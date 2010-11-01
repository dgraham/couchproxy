# encoding: UTF-8

module CouchProxy
  module Reduce

    # Sorts and merges reduce query results from many different source streams.
    class ReduceReducer < BaseReducer
      COUNT     = '_count'.freeze
      SUM       = '_sum'.freeze
      STATS     = '_stats'.freeze
      BUILT_INS = [COUNT, SUM, STATS]
      NONE      = Struct.new(:none) 

      # Args should contain the following keys:
      #  sources: List of stream sources used to identify from where
      #           streaming rows are arriving.
      #    limit: Maximum number of rows to return. If not specified, all
      #           rows are returned.
      #     skip: Number of rows at the start of the stream to skip before
      #           returning the rest. If not specified, no rows are skipped.
      # collator: A CouchProxy::Collator instance used to sort rows.
      #       fn: The JavaScript reduce function to apply to the rows.
      # reducers: A block that, when called, returns a CouchProxy::Reducer
      #           instance.
      def initialize(args)
        super(args)
        @fn, @reducers, @processes = args[:fn], args[:reducers], []
        @sorter = proc {|a, b| args[:collator].compare(a['key'], b['key']) }
      end

      def complete?
        super && @processes.empty?
      end

      private

      def process(&callback)
        @rows.sort!(&@sorter)
        sorted = [].tap do |rows|
          while @rows.any? && process?
            case @fn
              when SUM, COUNT then rows << sum(next_group)
              when STATS      then rows << stats(next_group)
              else view_server(next_group, callback)
            end
          end
        end
        callback.call(sorted) if built_in?
      end

      def next_group
        [].tap do |group|
          key = @rows.first['key']
          group << shift while @rows.any? && @rows.first['key'] == key
        end
      end

      def view_server(rows, callback)
        tracker = (@processes << {:value => NONE}).last
        values = rows.map {|row| row['value'] }
        @reducers.call.rereduce(@fn, values) do |result|
          success, value = result.flatten
          if success
            tracker[:value] = {:key => rows.first['key'], :value => value}
            ix = @processes.index {|t| t[:value] == NONE } || @processes.size
            finished = @processes.slice!(0, ix).map {|t| t[:value] }
            callback.call(finished)
          else
            callback.call(nil)
          end
        end
      end

      def sum(rows)
        value = rows.map {|row| row['value'] }.inject(:+)
        {:key => rows.first['key'], :value => value}
      end

      def stats(rows)
        values = rows.map {|row| row['value'] }
        min, max = values.map {|v| [v['min'], v['max']] }.flatten.minmax
        sum, count, sumsqr = %w[sum count sumsqr].map do |k|
          values.map {|v| v[k] }.inject(:+)
        end
        value = {:sum => sum, :count => count, :min => min, :max => max, :sumsqr => sumsqr}
        {:key => rows.first['key'], :value => value}
      end

      def built_in?
        BUILT_INS.include?(@fn)
      end
    end
  end
end
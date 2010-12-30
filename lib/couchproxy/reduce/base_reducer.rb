# encoding: UTF-8

module CouchProxy
  module Reduce

    # Sorts and merges results from many different source streams as the data
    # arrives from CouchDB over the network. This uses constant memory space to
    # do the merge so we can handle huge datasets streaming back from the
    # databases. Subclasses must provide a @sorter member variable, used to
    # sort streaming rows before they're processed.
    class BaseReducer
      KEY = 'key'.freeze
      ID  = 'id'.freeze

      # Args should contain the following keys:
      #  sources: List of stream sources used to identify from where
      #           streaming rows are arriving.
      #    limit: Maximum number of rows to return. If not specified, all
      #           rows are returned.
      #     skip: Number of rows at the start of the stream to skip before
      #           returning the rest. If not specified, no rows are skipped.
      def initialize(args)
        @sources, @limit, @skip = args.values_at(:sources, :limit, :skip)
        @sources = Hash[@sources.map {|s| [s, 0] }]
        @listeners = Hash.new {|h, k| h[k] = [] }
        @skip ||= 0
        @results, @returned, @skipped_rows = [], 0, 0
        @rows = MultiRBTree.new.tap {|t| t.readjust(@sorter) }
      end

      %w[results complete error].each do |name|
        define_method(name) do |&block|
          @listeners[name] << block
        end

        define_method("notify_#{name}") do |*args|
          @listeners[name].each do |block|
            block.call(*args)
          end
        end
        private "notify_#{name}"
      end

      # Gives the reducer more rows to process with their source connection.
      # Complete must be a boolean, signaling whether this stream of rows has
      # finished.
      def reduce(rows, source, complete)
        return if complete?
        rows.each do |row|
          row[:proxy_source] = source
          key = [row[KEY], row[ID]]
          @rows[key] = row
        end
        @sources[source] += rows.size
        @sources.delete(source) if complete
        process do |results|
          if results
            results = limit(skip(results))
            notify_results(results) if results.any?
            notify_complete if complete?
          else
            notify_error
          end
        end if process?
      end

      # Returns true if all streams of rows have arrived and the reduce
      # processing is complete.
      def complete?
        @sources.empty?
      end

      private

      def skip(sorted)
        if @skip > @skipped_rows
          @skipped_rows += sorted.slice!(0, @skip - @skipped_rows).size
        end
        sorted
      end

      def limit(sorted)
        return sorted unless @limit
        if @returned + sorted.size > @limit
          sorted = sorted[0, @limit - @returned]
        end
        @returned += sorted.size
        if @returned == @limit
          [@sources, @rows].each {|arr| arr.clear }
        end
        sorted
      end

      def process(&callback)
        sorted = [].tap do |rows|
          rows << shift while @rows.any? && process?
        end
        callback.call(sorted)
      end

      def shift
        @rows.shift.tap do |key, row|
          source = row.delete(:proxy_source)
          @sources[source] -= 1 if @sources.key?(source)
        end[1]
      end

      def process?
        !@sources.values.include?(0)
      end
    end
  end
end
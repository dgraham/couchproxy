# encoding: UTF-8

module CouchProxy
  module Reduce

    # Sorts and merges map query results from many different source streams.
    class MapReducer < BaseReducer

      # Args should contain the following keys:
      #  sources: List of stream sources used to identify from where
      #           streaming rows are arriving.
      #    limit: Maximum number of rows to return. If not specified, all
      #           rows are returned.
      #     skip: Number of rows at the start of the stream to skip before
      #           returning the rest. If not specified, no rows are skipped.
      # collator: A CouchProxy::Collator instance used to sort rows.
      def initialize(args)
        super(args)
        @sorter = proc do |a, b|
          key = args[:collator].compare(a['key'], b['key'])
          (key == 0) ? args[:collator].compare(a['id'], b['id']) : key
        end
      end
    end
  end
end
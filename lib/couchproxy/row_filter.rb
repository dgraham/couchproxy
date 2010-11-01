# encoding: UTF-8

module CouchProxy

  # A JSON::Stream::Parser listener that listens for the 'rows' key
  # in a CouchDB map/reduce result stream.  As row objects are parsed
  # they are sent to callbacks for processing.  Typically the callback
  # will perform some kind of reduce on the rows before sending them
  # to the client.
  #
  # Example usage:
  # parser = JSON::Stream::Parser.new
  # filter = CouchProxy::RowFilter.new(parser) do
  #   total_rows {|total| puts total }
  #   rows do |rows, complete|
  #     # process rows, complete tells us if this is the last row
  #   end
  # end
  class RowFilter < JSON::Stream::Builder
    TOTAL_ROWS = 'total_rows'.freeze
    MAX_ROWS   = 100

    def initialize(parser, &block)
      @listeners = Hash.new {|h, k| h[k] = [] }
      @total_rows_key = false
      super(parser)
      instance_eval(&block) if block_given?
    end

    %w[total_rows rows].each do |name|
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

    def key(key)
      super
      @total_rows_key = (@stack.size == 1 && key == TOTAL_ROWS)
    end

    def value(value)
      super
      if @total_rows_key
        @total_rows_key = false
        notify_total_rows(value)
      end
    end

    def end_document
      notify_rows(@stack.pop.obj['rows'], true)
    end

    def end_object
      super
      # row object complete
      if @stack.size == 2 && @stack[-1].obj.size >= MAX_ROWS
        notify_rows(@stack.pop.obj, false)
        @stack.push(JSON::Stream::ArrayNode.new)
      end
    end
  end
end

# encoding: UTF-8

module CouchProxy
  class Partition
    attr_reader :node, :num

    def initialize(node, num)
      @node, @num = node, num
    end

    def uri(db)
      "#{@node.uri.chomp('/')}/#{db}_#{@num}"
    end
  end
end

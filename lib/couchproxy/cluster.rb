# encoding: UTF-8

module CouchProxy
  class Cluster
    attr_reader :nodes

    def initialize(nodes, couchjs, reducers)
      @nodes, @partitions = [], 0
      nodes.each {|n| self << n }
      @reducers = Array.new(reducers) { Reducer.new(couchjs) }
    end

    def reducer
      @reducers[rand(@reducers.size)]
    end

    def <<(node)
      @nodes << node
      @partitions = @nodes.inject(0) do |acc, n|
        acc + n.partitions.size
      end
      self
    end

    def partition(doc_id)
      num = Zlib.crc32(doc_id.to_s).abs % @partitions
      node = @nodes.find {|n| n.hosts?(num) }
      node.partition(num)
    end

    def any_node
      @nodes[rand(@nodes.size)]
    end

    def any_partition
      any_node.any_partition
    end

    def partitions
      @nodes.map {|n| n.partitions}.flatten
    end
  end
end

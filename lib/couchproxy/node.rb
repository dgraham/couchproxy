# encoding: UTF-8

module CouchProxy
  class Node
    attr_reader :host, :port, :uri, :partitions

    def initialize(uri, partitions)
      parsed = URI.parse(uri)
      @uri, @host, @port = uri, parsed.host, parsed.port
      @partitions = partitions.map {|num| Partition.new(self, num) }
    end

    def hosts?(partition)
      @partitions.any? {|p| p.num == partition }
    end

    def partition(num)
      @partitions.find {|p| p.num == num }
    end

    def any_partition
      @partitions[rand(@partitions.size)]
    end
  end
end

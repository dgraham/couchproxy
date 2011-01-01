# encoding: UTF-8

module CouchProxy
  module Rack
    class Doc < Base
      def get
        partition = cluster.partition(request.doc_id)
        request.rewrite_proxy_url!(partition.num)
        proxy_to(partition.node)
      end
      alias :put    :get
      alias :delete :get
      alias :head   :get
    end
  end
end

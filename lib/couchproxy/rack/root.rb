# encoding: UTF-8

module CouchProxy
  module Rack
    class Root < Base
      alias :get  :proxy_to_any_node
      alias :head :proxy_to_any_node
    end
  end
end

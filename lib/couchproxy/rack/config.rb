# encoding: UTF-8

module CouchProxy
  module Rack
    class Config < Base
      alias :get :proxy_to_any_node

      def put
        proxy_to_all_nodes do |responses|
          send_response(responses.first.response_header.status,
            response_headers, [responses.first.response])
        end
      end
    end
  end
end

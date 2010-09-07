# encoding: UTF-8

module CouchProxy
  module Rack
    class RevsLimit < Base
      alias :get :proxy_to_any_partition

      def put
        proxy_to_all_partitions do |responses|
          ok = responses.map {|res| JSON.parse(res.response)['ok'] }
          body = {:ok => !ok.include?(false)}
          send_response(responses.first.response_header.status,
            response_headers, [body.to_json])
        end
      end
    end
  end
end

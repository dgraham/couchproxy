# encoding: UTF-8

module CouchProxy
  module Rack
    class AllDatabases < Base
      SUFFIX = /_\d+$/

      def get
        proxy_to_all_nodes do |responses|
          dbs = responses.map do |res|
            JSON.parse(res.response).map {|name| name.gsub(SUFFIX, '') }
          end.flatten.uniq.sort
          send_response(responses.first.response_header.status,
            response_headers, [dbs.to_json])
        end
      end

      def head
        # FIXME
      end
    end
  end
end

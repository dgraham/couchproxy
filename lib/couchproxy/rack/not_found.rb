# encoding: UTF-8

module CouchProxy
  module Rack
    class NotFound < Base
      NOT_FOUND = '{"error":"not_found","reason":"missing"}'.freeze

      def method_missing(name)
        send_response(404, response_headers, [NOT_FOUND])
      end
    end
  end
end

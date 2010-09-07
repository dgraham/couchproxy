# encoding: UTF-8

module CouchProxy
  module Rack
    class Database < Base
      def get
        proxy_to_all_partitions do |responses|
          doc = {
            :db_name => request.db_name,
            :disk_size => 0,
            :doc_count => 0,
            :doc_del_count => 0,
            :compact_running => false,
            :compact_running_partitions => []}

          responses.each do |res|
            result = JSON.parse(res.response)
            doc[:compact_running] ||= result['compact_running']
            doc[:compact_running_partitions] << result['db_name'] if result['compact_running']
            %w[disk_size doc_count doc_del_count].each do |k|
              doc[k.to_sym] += result[k]
            end
            doc[:compact_running_partitions].sort!
          end
          send_response(responses.first.response_header.status,
            response_headers, [doc.to_json])
        end
      end

      def post
        begin
          doc = JSON.parse(request.content)
        rescue
          send_response(400, response_headers, INVALID_JSON)
          return
        end

        unless doc['_id']
          uuids(1) do |uuids|
            if uuids
              doc['_id'] = uuids.first
              partition = cluster.partition(doc['_id'])
              request.content = doc.to_json
              request.rewrite_proxy_url!(partition.num)
              proxy_to(partition.node)
            else
              send_error_response
            end
          end
        else
          partition = cluster.partition(doc['_id'])
          request.rewrite_proxy_url!(partition.num)
          proxy_to(partition.node) do
            if design?(doc['_id'])
              replicate_to_all_partitions(partition, doc['_id'])
            end
          end
        end
      end

      def put
        proxy_to_all_partitions do |responses|
          res = responses.first
          head = response_headers.tap do |h|
            h['Location'] = rewrite_location(res.response_header.location)
          end
          send_response(res.response_header.status, head, res.response)
        end
      end

      def delete
        proxy_to_all_partitions do |responses|
          send_response(responses.first.response_header.status,
            response_headers, responses.first.response)
        end
      end

      def head
        # FIXME
      end
    end
  end
end

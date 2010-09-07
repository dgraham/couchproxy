# encoding: UTF-8

module CouchProxy
  module Rack
    class BulkDocs < Base
      def post
        begin
          docs = JSON.parse(request.content)['docs']
        rescue
          send_response(400, response_headers, INVALID_JSON)
          return
        end

        missing = docs.select {|doc| !doc['_id'] }
        if missing.any?
          uuids(missing.size) do |uuids|
            if uuids
              missing.each {|doc| doc['_id'] = uuids.shift }
              save(docs)
            else
              send_error_response
            end
          end
        else
          save(docs)
        end
      end

      private

      def save(docs)
        designs, normals = docs.partition {|d| design?(d['_id']) }

        partitions = Hash.new {|h, k| h[k] = [] }
        normals.each do |doc|
          partitions[cluster.partition(doc['_id'])] << doc
        end
        design_partition = cluster.any_partition
        partitions[design_partition] += designs

        req = EM::MultiRequest.new
        partitions.each do |p, d|
          url = "#{p.uri(request.db_name)}/_bulk_docs"
          req.add EM::HttpRequest.new(url).post(:head => proxy_headers,
            :body => {:docs => d}.to_json)
        end

        callback = multi do |responses|
          total = responses.map {|res| JSON.parse(res.response) }.flatten
          total = docs.map do |doc|
            total.find {|d| d['id'] == doc['_id'] }
          end
          sender = proc do
            send_response(responses.first.response_header.status,
              response_headers, [total.to_json])
          end
          if designs.any?
            replicate_to_all_partitions(design_partition,
              designs.map {|d| d['_id'] }, &sender)
          else
            sender.call
          end
        end
        req.callback(&callback)
      end
    end
  end
end

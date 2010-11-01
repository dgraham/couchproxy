# encoding: UTF-8

module CouchProxy
  module Rack
    class DesignDoc < Base
      QUERY     = /_view\/.+$/
      INFO      = /\/_info$/
      VIEW_NAME = /_view\/(.*)$/
      REDUCE_ERROR = '{"error":"query_parse_error","reason":"Invalid URL parameter `reduce` for map view."}'.freeze

      def get
        case request.path_info
          when QUERY then query
          when INFO  then info
          else proxy_to_any_partition
        end
      end

      def head
        case request.path_info
          when QUERY then
            proxy_to_all_partitions do |responses|
              etags = responses.map {|r| r.response_header.etag }
              head = response_headers.tap do |h|
                h['ETag'] = etag(etags)
              end
              send_response(responses.first.response_header.status, head, [])
            end
          else proxy_to_any_partition
        end
      end

      def post
        # FIXME same as get, but body can have keys in it
      end

      def put
        partition = cluster.any_partition
        request.rewrite_proxy_url!(partition.num)
        uri = "#{partition.node.uri}#{@request.fullpath}"
        http = EM::HttpRequest.new(uri).put(:head => proxy_headers,
          :body => request.content)
        http.callback do |res|
          head = response_headers
          sender = proc do
            send_response(res.response_header.status, head, [res.response])
          end
          if success?(res)
            head.tap do |h|
              h['ETag'] = res.response_header.etag
              h['Location'] = rewrite_location(res.response_header.location)
            end
            replicate_to_all_partitions(partition, request.doc_id, &sender)
          else
            sender.call
          end
        end
        http.errback { send_error_response }
      end

      def delete
        proxy_to_all_partitions do |responses|
          head = response_headers.tap do |h|
            h['ETag'] = responses.first.response_header.etag
          end
          send_response(responses.first.response_header.status,
            head, responses.first.response)
        end
      end

      private

      def query_params
        {}.tap do |params|
          params[:reduce] = [nil, 'true'].include?(request['reduce'])
          params[:group] = (request['group'] == 'true')
          params[:descending] = (request['descending'] == 'true')
          params[:limit] = request['limit'] || ''
          params[:limit] = params[:limit].empty? ? nil : params[:limit].to_i
          params[:skip] = (params[:limit] == 0) ? 0 : delete_query_param('skip').to_i
          delete_query_param('limit') if params[:skip] > (params[:limit] || 0)
          params[:collator] = CouchProxy::Collator.new(params[:descending])
        end
      end

      def send_chunk(body, chunk)
        body.call(["%s\r\n%s\r\n" % [chunk.bytesize.to_s(16), chunk]])
      end

      def query
        params = query_params
        view_doc do |doc|
          if doc
            fn = doc['views'][view_name]['reduce']
            if request['reduce'] && fn.nil?
              send_response(400, response_headers, [REDUCE_ERROR])
            elsif params[:reduce] && fn
              reduce(params, fn)
            else
              map(params)
            end
          else
            send_error_response
          end
        end
      end

      def map(params)
        reducer = proc do |sources|
          args = params.merge({:sources => sources})
          CouchProxy::Reduce::MapReducer.new(args)
        end
        spray(reducer) do |total_rows|
          offset = [params[:skip], total_rows].min
          '],"total_rows":%s,"offset":%s}' % [total_rows, offset]
        end
      end

      def reduce(params, fn)
        reducer = proc do |sources|
          args = params.merge({:sources => sources, :fn => fn,
            :reducers => cluster.method(:reducer)})
          CouchProxy::Reduce::ReduceReducer.new(args)
        end
        spray(reducer) {|total_rows| ']}' }
      end

      def spray(reducer, &finish)
        body, etags = DeferrableBody.new, []

        requests = cluster.partitions.map do |p|
          uri = "#{p.node.uri}#{request.rewrite_proxy_url(p.num)}"
          uri << "?#{request.query_string}" unless request.query_string.empty?
          EM::HttpRequest.new(uri).send(request.request_method.downcase,
            :head => proxy_headers, :body => request.content)
        end

        started = false
        start = proc do
          started = true
          headers = response_headers.tap do |h|
            h['Transfer-Encoding'] = 'chunked'
            h['ETag'] = etag(etags)
          end
          send_response(200, headers, body)
          send_chunk(body, '{"rows":[')
        end

        closed = false
        close = proc do
          unless closed
            closed = true
            requests.each {|req| req.close_connection }
            send_error_response
          end
        end

        total_rows = 0
        reducer = reducer.call(requests)
        reducer.error(&close)
        reducer.results do |results|
          start.call unless started
          json = results.map {|row| row.to_json }.join(',')
          json << ',' unless reducer.complete?
          send_chunk(body, json)
        end
        reducer.complete do
          start.call unless started
          requests.each {|req| req.close_connection }
          chunk = finish.call(total_rows)
          [chunk, ''].each {|c| send_chunk(body, c) }
          body.succeed
        end

        multi = EM::MultiRequest.new
        requests.each do |req|
          parser = JSON::Stream::Parser.new
          CouchProxy::RowFilter.new(parser) do
            total_rows {|total| total_rows += total }
            rows do |rows, complete|
              reducer.reduce(rows, req, complete)
            end
          end
          req.stream {|chunk| parser << chunk unless closed }
          req.errback(&close)
          req.headers do |h|
            etags << h['ETAG']
            close.call unless success?(req)
          end
          multi.add(req)
        end
      end

      def info
        proxy_to_all_partitions do |responses|
          status = total = nil
          responses.shift.tap do |res|
            status = res.response_header.status
            total = JSON.parse(res.response)
          end
          responses.each do |res|
            doc = JSON.parse(res.response)
            %w[disk_size waiting_clients].each do |k|
              total['view_index'][k] += doc['view_index'][k]
            end
            %w[compact_running updater_running waiting_commit].each do |k|
              total['view_index'][k] ||= doc['view_index'][k]
            end
          end
          %w[update_seq purge_seq].each {|k| total['view_index'].delete(k) }
          send_response(status, response_headers, [total.to_json])
        end
      end

      def success?(response)
        (200...300).include?(response.response_header.status)
      end

      def etag(etags)
        etags = etags.map {|etag| etag || '' }.sort.join
        '"%s"' % Digest::SHA256.hexdigest(etags)
      end

      def view_doc_id
        request.doc_id.split('/')[0..1].join('/')
      end

      def view_name
        request.doc_id.match(VIEW_NAME)[1]
      end

      def view_doc(&callback)
        db = cluster.any_partition.uri(request.db_name)
        http = EM::HttpRequest.new("#{db}/#{view_doc_id}").get
        http.errback { callback.call(nil) }
        http.callback do |res|
          if res.response_header.status == 200
            callback.call(JSON.parse(res.response))
          else
            callback.call(nil)
          end
        end
      end
    end
  end
end
# encoding: UTF-8

module CouchProxy
  module Rack
    class DesignDoc < Base
      QUERY     = /_view\/.+$/
      INFO      = /\/_info$/
      VIEW_NAME = /_view\/(.*)$/
      COUNT     = '_count'.freeze
      SUM       = '_sum'.freeze
      STATS     = '_stats'.freeze
      REDUCE_ERROR = '{"error":"query_parse_error","reason":"Invalid URL parameter `reduce` for map view."}'.freeze

      def get
        case request.path_info
          when QUERY then query
          when INFO  then info
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
          if (200...300).include?(res.response_header.status)
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

      def head
        # FIXME
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

      def query
        params = query_params
        proxy_to_all_partitions do |responses|
          view_doc do |doc|
            if doc
              fn = doc['views'][view_name]['reduce']
              if request['reduce'] && fn.nil?
                send_response(400, response_headers, [REDUCE_ERROR])
              elsif params[:reduce] && fn
                reduce(params, responses, fn)
              else
                map(params, responses)
              end
            else
              send_error_response
            end
          end
        end
      end

      def map(params, responses)
        total = {:total_rows => 0, :offset => 0, :rows =>[]}
        responses.each do |res|
          result = JSON.parse(res.response)
          %w[total_rows rows].each {|k| total[k.to_sym] += result[k] }
        end
        total[:rows].sort! do |a, b|
          key = params[:collator].compare(a['key'], b['key'])
          (key == 0) ? params[:collator].compare(a['id'], b['id']) : key
        end
        total[:rows].slice!(0, params[:skip])
        total[:rows].slice!(params[:limit], total[:rows].size) if params[:limit]
        total[:offset] = [params[:skip], total[:total_rows]].min
        send_response(responses.first.response_header.status,
          response_headers, [total.to_json])
      end

      def reduce(params, responses, fn)
        total = {:rows =>[]}
        responses.each do |res|
          result = JSON.parse(res.response)
          total[:rows] += result['rows']
        end
        groups = total[:rows].group_by {|row| row['key'] }
        case fn
        when SUM, COUNT
          sum(params, groups)
        when STATS
          stats(params, groups)
        else
          view_server(params, fn, groups)
        end
      end

      def view_server(params, fn, groups)
        reduced = {:rows => []}
        groups.each do |key, rows|
          values = rows.map {|row| row['value'] }
          cluster.reducer.rereduce(fn, values) do |result|
            success, value = result.flatten
            if success
              reduced[:rows] << {:key => key, :value => value}
              if reduced[:rows].size == groups.size
                reduced[:rows].sort! do |a, b|
                  params[:collator].compare(a[:key], b[:key])
                end
                send_response(200, response_headers, [reduced.to_json])
              end
            else
              send_error_response
            end
          end
        end
      end

      def sum(params, groups)
        reduced = {:rows => []}
        groups.each do |key, rows|
          value = rows.map {|row| row['value'] }.inject(:+)
          reduced[:rows] << {:key => key, :value => value}
        end
        reduced[:rows].sort! do |a, b|
          params[:collator].compare(a[:key], b[:key])
        end
        send_response(200, response_headers, [reduced.to_json])
      end

      def stats(groups)
        reduced = {:rows => []}
        groups.each do |key, rows|
          values = rows.map {|row| row['value'] }
          min, max = values.map {|v| [v['min'], v['max']] }.flatten.minmax
          sum, count, sumsqr = %w[sum count sumsqr].map do |k|
            values.map {|v| v[k] }.inject(:+)
          end
          value = {:sum => sum, :count => count, :min => min, :max => max,
            :sumsqr => sumsqr}
          reduced[:rows] << {:key => key, :value => value}
        end
        reduced[:rows].sort! do |a, b|
          params[:collator].compare(a[:key], b[:key])
        end
        send_response(200, response_headers, [reduced.to_json])
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

# encoding: UTF-8

module CouchProxy
  module Rack
    class Base
      DESIGN_ID = /^_design\/.+/
      METHODS = [:get, :put, :post, :delete, :head].freeze
      INVALID_JSON = '{"error":"bad_request","reason":"invalid UTF-8 JSON"}'.freeze

      attr_reader :request, :cluster

      def initialize(request, cluster)
        @request, @cluster = request, cluster
      end

      def method_missing(name)
        allowed = methods.map {|m| m.to_sym } & METHODS
        allowed = allowed.map {|m| m.to_s.upcase }.join(',')
        body = "{\"error\:\"method_not_allowed\",\"reason\":\"Only #{allowed} allowed\"}"
        send_response(405, response_headers, [body])
      end

      def proxy_to(node, &finish)
        head_proxy_to(node, &finish) if @request.request_method == 'HEAD'

        body, started = DeferrableBody.new, false
        uri = "#{node.uri}#{@request.fullpath}"
        http = EM::HttpRequest.new(uri)
        res = http.send(@request.request_method.downcase,
          :head => proxy_headers, :body => @request.content)
        res.stream do |chunk|
          unless started
            started = true
            head = normalize(res.response_header).tap do |h|
              h['Server'] = "CouchProxy/#{CouchProxy::VERSION}"
              if res.response_header.location
                h['Location'] = rewrite_location(res.response_header.location)
              end
            end
            send_response(res.response_header.status, head, body)
          end
          body.call([chunk])
        end
        res.callback do
          body.succeed
          finish.call if finish
        end
        res.errback { send_error_response }
      end

      def rewrite_location(uri)
        URI.parse(request.url).tap do |req|
          req.query, req.user, req.password = nil
          req.path = URI.parse(uri).path.gsub(
            /^\/#{request.db_name}_\d+/, "/#{request.db_name}")
        end.to_s
      end

      def proxy_to_any_node
        proxy_to(@cluster.any_node)
      end

      def proxy_to_any_partition
        partition = @cluster.any_partition
        request.rewrite_proxy_url!(partition.num)
        proxy_to(partition.node)
      end

      def proxy_to_all_nodes(&callback)
        method = request.request_method.downcase
        multi = EM::MultiRequest.new
        @cluster.nodes.each do |n|
          uri = "#{n.uri}#{@request.fullpath}"
          req = EM::HttpRequest.new(uri).send(method,
            :head => proxy_headers, :body => @request.content)
          multi.add(req)
        end
        multi.callback(&multi(&callback)) if callback
      end

      def proxy_to_all_partitions(&callback)
        method = request.request_method.downcase
        multi = EM::MultiRequest.new
        @cluster.partitions.each do |p|
          uri = "#{p.node.uri}#{@request.rewrite_proxy_url(p.num)}"
          uri << "?#{@request.query_string}" unless @request.query_string.empty?
          multi.add EM::HttpRequest.new(uri).send(method,
            :head => proxy_headers, :body => @request.content)
        end
        multi.callback(&multi(&callback)) if callback
      end

      def replicate_to_all_partitions(source, *doc_ids, &callback)
        multi = EM::MultiRequest.new
        (@cluster.partitions - [source]).each do |p|
          task = {
            :source => source.uri(request.db_name),
            :target => p.uri(request.db_name),
            :doc_ids => doc_ids.flatten}
          multi.add EM::HttpRequest.new("#{p.node.uri}/_replicate").post(
            :head => proxy_headers, :body => task.to_json)
        end
        multi.callback(&multi(&callback)) if callback
      end

      def uuids(count, &callback)
        http = EM::HttpRequest.new("#{@cluster.any_node.uri}/_uuids?count=#{count}").get
        http.errback { callback.call(nil) }
        http.callback do |res|
          if res.response_header.status == 200
            uuids = JSON.parse(res.response)['uuids']
            callback.call(uuids)
          else
            callback.call(nil)
          end
        end
      end

      def send_response(*args)
        @request.env['async.callback'].call(args)
      end

      def send_error_response
        send_response(503, response_headers, [])
      end

      private

      def multi(&callback)
        proc do |multi|
          if multi.responses[:failed].empty?
            err = multi.responses[:succeeded].find do |res|
              res.response_header.status >= 400
            end
            if err
              send_response(err.response_header.status,
                response_headers, err.response)
            else
              callback.call(multi.responses[:succeeded])
            end
          else
            send_error_response
          end
        end
      end

      def head_proxy_to(node, &finish)
        uri = "#{node.uri}#{@request.fullpath}"
        http = EM::HttpRequest.new(uri).head(:head => proxy_headers)
        http.callback do 
          status = http.response_header.status
          headers = normalize(http.response_header)
          send_response(status, headers, [])
          finish.call if finish
        end
        http.errback { send_error_response }
        throw :async
      end

      def normalize(headers)
        headers.keys.inject({}) do |acc, k|
          normalized = k.sub('HTTP_', '').split('_').map {|p| p.capitalize }.join('-')
          acc.tap {|h| h[normalized] = headers[k] }
        end
      end

      def proxy_headers
        keys = @request.env.keys.select {|k| k.start_with?('HTTP_') || k == 'CONTENT_TYPE' }
        keys -= %w[HTTP_HOST HTTP_VERSION]
        headers = keys.inject({}) do |acc, k|
          acc.tap {|h| h[k] = @request.env[k] }
        end
        normalize(headers)
      end

      def response_headers
        type = @request.json? ? "application/json" : "text/plain;charset=utf-8"
        {
          "Server" => "CouchProxy/#{CouchProxy::VERSION}",
          "Date" => Time.now.httpdate,
          "Content-Type" => type,
          "Cache-Control" => "must-revalidate"
        }
      end

      def design?(doc_id)
        doc_id =~ DESIGN_ID
      end

      def delete_query_param(param)
        value = @request.GET.delete(param)
        if value
          @request.env['QUERY_STRING'] = ::Rack::Utils.build_query(@request.GET)
        end
        value
      end
    end
  end
end

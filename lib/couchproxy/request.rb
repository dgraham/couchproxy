module Rack
  # Add a few helper methods to Rack's Request class.
  class Request
    def json?
      if accept = @env['HTTP_ACCEPT']
        accept.tr(' ', '').split(',').include?('application/json')
      end
    end

    def db_name
      parse_db_name_and_doc_id[0]
    end

    def doc_id
      parse_db_name_and_doc_id[1]
    end

    def rewrite_proxy_url(partition_num)
      path_info.sub(/^\/#{db_name}/, "/#{db_name}_#{partition_num}")
    end

    def rewrite_proxy_url!(partition_num)
      @env['PATH_INFO'] = rewrite_proxy_url(partition_num)
    end

    def content
      unless defined? @proxy_content
        body.rewind
        @proxy_content = body.read
        body.rewind
      end
      @proxy_content
    end

    def content=(body)
      @proxy_content = body
      @env['CONTENT_LENGTH'] = body.bytesize
    end

    private

    def parse_db_name_and_doc_id
      unless defined? @db_name
        path = @env['REQUEST_PATH'][1..-1].chomp('/')
        @db_name, @doc_id = path.split('/', 2).map {|n| ::Rack::Utils.unescape(n) }
      end
      [@db_name, @doc_id]
    end
  end
end

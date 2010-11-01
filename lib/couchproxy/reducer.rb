# encoding: UTF-8

module CouchProxy
  class Reducer
    def initialize(couchjs)
      @couchjs, @conn = "#{couchjs} #{mainjs(couchjs)}", nil
    end

    def rereduce(fn, values, &callback)
      connect unless @conn
      @conn.rereduce(fn, values, callback)
    end

    private

    def mainjs(couchjs)
      File.expand_path('../../share/couchdb/server/main.js', couchjs)
    end

    def connect
      @conn = EM.popen(@couchjs, ReduceProcess, proc { @conn = nil })
    end
  end

  class ReduceProcess < EventMachine::Connection
    def initialize(unbind=nil)
      @unbind, @connected, @callbacks, @deferred = unbind, false, [], []
    end

    def post_init
      @connected = true
      @deferred.slice!(0, @deferred.size).each do |fn, values, callback|
        rereduce(fn, values, callback)
      end
    end

    def rereduce(fn, values, callback)
      if @connected
        @callbacks << callback
        send_data(["rereduce", [fn], values].to_json + "\n")
      else
        @deferred << [fn, values, callback]
      end
    end

    def receive_data(data)
      data.split("\n").each do |line|
        @callbacks.shift.call(JSON.parse(line))
      end
    end

    def unbind
      @connected = false
      @unbind.call if @unbind
    end
  end
end

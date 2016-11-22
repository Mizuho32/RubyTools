require 'em-websocket'

WS_PORT = ARGV[1] || 5000
PORT = ARGV[2]    || 4000

ws = Thread.new do
  p WS_PORT
  EM::WebSocket.start(host: 'localhost', port: WS_PORT){ |con|
    con.onopen do
      puts "opened"
    end

    con.onclose do
      @documents.delete_if{|k,v| v.equal?(con) }
      puts "closed"
    end

    con.onmessage do |msg|
      @documents[msg] = con
    end
  }
end

ws.join()

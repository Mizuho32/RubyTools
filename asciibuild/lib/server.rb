require 'webrick'
require 'date'
require 'cgi'

require 'filewatcher'
require 'oga'
require 'em-websocket'

require 'lib/templ'

module Server
  WS_PORT = ARGV[1] || 5000
  PORT = ARGV[2]    || 4000
  DIR = Pathname(ARGV[3] || ?.).expand_path.to_s
  CONFIG_FILE = ".config"
  class << self
    attr_accessor :cmd_config
  end
  self.cmd_config = File.open(CONFIG_FILE, "r").read rescue FileUtils.touch(".config") && ""

  @documents = {}
  threads = []

  threads << http = Thread.new do
    server = WEBrick::HTTPServer.new({DocumentRoot: './', BindAddress: '127.0.0.1', Port: PORT})
    server.mount_proc("/config"){|req, res|
      res.body = <<-"EOF"
<!DOCTYPE html>
<html>
  <form action="http://localhost:#{PORT}/post" method="post">
    <input type="text" name="option" value="#{self.cmd_config}"></input>
    <input type="submit" value="設定"></input>
  </form>
</html>
EOF
    }
    server.mount_proc("/post"){|req, res|
      puts "cmd_opt=#{ self.cmd_config = CGI.unescape(p req.body[/=(.*)$/, 1]) }"
      File.open(CONFIG_FILE, "w"){|f| f.write(self.cmd_config) }
      res.body = '<html><meta http-equiv="refresh" content="0;URL=/config"></html>'
    }
    trap("INT"){ 
      server.shutdown
      threads.each{|n| n.kill }
      exit 0
    }
    server.start
  end

  threads << ws = Thread.new do
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

  ENV.each{|k,v|
    if k !~ /LANG|PATH/ then
      ENV[k] = nil
    end
  }

  FileWatcher.new(["#{DIR}/**/*.adoc"]).watch do |fullname|
    name = fullname.sub(/\.adoc$/, "")
    p fullname, name

    #puts Open3.capture3({"PATH" => PATH}, "pwd")
    html = (res = Open3.capture3({"PATH" => PATH}, "cd #{DIR};asciidoctor #{self.cmd_config} -o - #{fullname}"))[0]
    puts res[1], res[2]

    if res[2].exitstatus != 0 then
      puts Open3.capture3("which asciidoctor")
      next
    end

    key = fullname.sub(DIR+?/, "")
    out = insert( html, js(key, WS_PORT) )
    File.open("#{name}.html", "w"){|f|
      f.write(out.to_xml)
    }
    @documents[key]&.send("hi")
  end
end

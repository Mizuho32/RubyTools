# frozen_string_literal: true

require "net/http"
require "uri"
require "thread"

module WiFiKeyboard
  class Client
    attr_reader :host, :port

    def initialize(host_port)
      parts = host_port.split(":")
      @host = parts[0]
      @port = (parts[1] || "7777").to_i
      @seq  = nil
      @seq_mutex = Mutex.new
      @send_queue = Queue.new
      @sender_http = nil
      @submit_http = nil
      @submit_mutex = Mutex.new
      @debug_enabled = ENV["WIFIKEYBOARD_DEBUG"] == "1"
      @sender_thread = Thread.new { sender_loop }
    end

    # Send full text to Android via POST /form
    def submit(text)
      req  = Net::HTTP::Post.new("/form")
      body = text.to_s
      # Match original key.html behavior: raw body, no `text=` wrapper.
      req["Content-Type"] = "application/x-www-form-urlencoded"
      req["Content-Length"] = body.bytesize.to_s
      req.body = body
      @submit_mutex.synchronize do
        res = submit_http.request(req)
        return res.code == "200"
      rescue => e
        debug_log("client.submit error=#{e.class}: #{e.message} -> reconnect and retry")
        close_submit_http
        res = submit_http.request(req)
        return res.code == "200"
      end
    rescue => e
      raise ConnectionError, e.message
    end

    # Send a key event via GET /key?seq,data
    # data examples:
    #   "C65,"  — character 'A'
    #   "D13,"  — keydown Enter
    #   "U13,"  — keyup Enter
    def send_key(data)
      @send_queue << data
      true
    rescue => e
      debug_log("client.send_key error=#{e.class}: #{e.message}")
      raise ConnectionError, e.message
    end

    # Send keydown + keyup for a given keycode
    def send_keycode(code)
      send_key("D#{code},")
      send_key("U#{code},")
    end

    def close
      @send_queue << :__close__
      @sender_thread&.join(0.5)
      close_sender_http
      close_submit_http
    rescue
      nil
    end

    # Fetch current text from Android text field
    def fetch_text
      http = build_http
      res  = http.get("/text")
      res.code == "200" ? res.body : nil
    rescue => e
      raise ConnectionError, e.message
    end

    # Check connectivity; returns :connected, :problem, :multi, or :failure
    def ping
      http = build_http
      res  = http.get("/")
      return :failure unless res.code == "200"

      seq = extract_seq_confirmed(res.body)
      if seq
        @seq_mutex.synchronize do
          @seq = seq if @seq.nil? || seq > @seq
        end
      end

      :connected
    rescue
      :failure
    end

    private

    def build_http
      http = Net::HTTP.new(@host, @port)
      http.open_timeout = 3
      http.read_timeout = 5
      http
    end

    def next_seq
      @seq_mutex.synchronize do
        if @seq.nil?
          http = build_http
          sync_seq_from_root!(http)
        end
        @seq += 1
      end
    end

    def sync_seq_from_root!(http)
      res = http.get("/")
      unless res.code == "200"
        raise ConnectionError, "failed to fetch root page: HTTP #{res.code}"
      end

      seq = extract_seq_confirmed(res.body)
      unless seq
        raise ConnectionError, "seqConfirmed not found in root page"
      end

      @seq = seq
    end

    def extract_seq_confirmed(html)
      m = html.match(/seqConfirmed\s*=\s*(\d+)\s*;/)
      m && m[1].to_i
    end

    def sender_loop
      loop do
        data = @send_queue.pop
        break if data == :__close__
        perform_send_key(data)
      end
    rescue => e
      debug_log("client.sender_loop error=#{e.class}: #{e.message}")
      close_sender_http
      retry
    ensure
      close_sender_http
    end

    def perform_send_key(data)
      seq = next_seq
      path = "/key?#{seq},#{data}"
      debug_log("client.send_key path=#{path}")
      res = sender_http.get(path)
      debug_log("client.send_key response code=#{res.code} body=#{res.body.inspect}")
      res.code == "200"
    rescue => e
      debug_log("client.send_key perform_error=#{e.class}: #{e.message} -> reconnect and retry")
      close_sender_http
      begin
        res = sender_http.get(path)
        debug_log("client.send_key retry_response code=#{res.code} body=#{res.body.inspect}")
        res.code == "200"
      rescue => e2
        debug_log("client.send_key retry_error=#{e2.class}: #{e2.message}")
        false
      end
    end

    def sender_http
      return @sender_http if @sender_http&.started?

      @sender_http = Net::HTTP.new(@host, @port)
      @sender_http.open_timeout = 3
      @sender_http.read_timeout = 5
      @sender_http.keep_alive_timeout = 30
      @sender_http.start
      @sender_http
    end

    def submit_http
      return @submit_http if @submit_http&.started?

      @submit_http = Net::HTTP.new(@host, @port)
      @submit_http.open_timeout = 3
      @submit_http.read_timeout = 5
      @submit_http.keep_alive_timeout = 30
      @submit_http.start
      @submit_http
    end

    def close_sender_http
      return unless @sender_http

      @sender_http.finish if @sender_http.started?
    rescue
      nil
    ensure
      @sender_http = nil
    end

    def close_submit_http
      return unless @submit_http

      @submit_http.finish if @submit_http.started?
    rescue
      nil
    ensure
      @submit_http = nil
    end

    def debug_log(msg)
      return unless @debug_enabled

      line = "#{Time.now.strftime('%Y-%m-%d %H:%M:%S.%L')} [CLIENT] #{msg}\n"
      File.open(ENV.fetch("WIFIKEYBOARD_DEBUG_LOG", "/tmp/wifikeyboard_debug.log"), "a") { |f| f.write(line) }
      $stderr.write(line) if ENV["WIFIKEYBOARD_DEBUG_STDERR"] == "1"
    rescue
      nil
    end
  end

  class ConnectionError < StandardError; end
end

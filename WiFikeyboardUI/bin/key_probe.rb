#!/usr/bin/env ruby
# frozen_string_literal: true

require "curses"
require_relative "../lib/wifi_keyboard/input_decoder"

class KeyProbe
  MAX_LINES = 18

  def initialize
    @decoder = WiFiKeyboard::InputDecoder.new
    @lines = []
    @protocol_status = "unknown"
  end

  def run
    setup_curses
    enable_enhanced_keyboard_input
    @protocol_status = probe_keyboard_protocol

    loop do
      draw
      raw = Curses.stdscr.getch
      next if raw.nil?

      break if handle_key(raw) == :quit
    end
  ensure
    disable_enhanced_keyboard_input
    Curses.close_screen
  end

  private

  def setup_curses
    begin
      Curses.setlocale(Curses::LC_ALL, "")
    rescue StandardError
    end

    Curses.init_screen
    Curses.noecho
    Curses.cbreak
    Curses.stdscr.keypad(true)
    Curses.stdscr.nodelay = false
  end

  def draw
    rows = Curses.lines
    cols = Curses.cols

    Curses.clear
    header = "Key Probe (^C/q: quit)  Enhanced input: #{@protocol_status}"
    Curses.setpos(0, 0)
    Curses.addstr(header.ljust(cols)[0, cols])

    help = "Press Ctrl/Shift/Alt/arrows and watch raw + decoded events"
    Curses.setpos(1, 0)
    Curses.addstr(help.ljust(cols)[0, cols])

    start = [@lines.length - (rows - 3), 0].max
    view = @lines[start, rows - 3] || []
    view.each_with_index do |line, idx|
      Curses.setpos(2 + idx, 0)
      Curses.addstr(line.ljust(cols)[0, cols])
    end

    Curses.refresh
  end

  def handle_key(raw)
    code = @decoder.key_code(raw)

    if quit_key?(raw, code)
      add_line("quit raw=#{raw.inspect} code=#{code.inspect}")
      return :quit
    end

    if code == 27
      event = @decoder.read_escape_event(raw, Curses.stdscr)
      if event
        add_line("ESC decoded=#{event.inspect}")
      else
        consumed = @decoder.consume_escape_sequence(Curses.stdscr)
        add_line("ESC undecoded consumed=#{consumed} raw=#{raw.inspect}")
      end
      return nil
    end

    if raw.is_a?(String)
      add_line("RAW str=#{raw.inspect} bytes=#{raw.bytes.inspect} code=#{code}")
    else
      add_line("RAW int=#{raw.inspect} code=#{code}")
    end

    nil
  end

  def quit_key?(raw, code)
    return true if code == 3
    return false unless raw.is_a?(String)

    raw.downcase == "q"
  end

  def add_line(line)
    ts = Time.now.strftime("%H:%M:%S.%L")
    @lines << "#{ts} #{line}"
    @lines.shift while @lines.length > MAX_LINES * 4
  end

  def enable_enhanced_keyboard_input
    return unless $stdout.tty?

    # Push keyboard mode stack and enable disambiguate + event types + all keys.
    $stdout.write("\e[>1u\e[=11;1u")
    $stdout.flush
  rescue StandardError
    nil
  end

  def probe_keyboard_protocol
    return "stdout not tty" unless $stdout.tty?

    # Query current kitty keyboard progressive-enhancement flags.
    $stdout.write("\e[?u")
    $stdout.flush

    response = read_csi_response(timeout_ms: 180)
    if response && (m = response.match(/\e\[\?(\d+)u/))
      "reply flags=#{m[1]}"
    else
      "no reply"
    end
  rescue StandardError => e
    "probe error #{e.class}: #{e.message}"
  end

  def read_csi_response(timeout_ms:)
    stdscr = Curses.stdscr
    prev = stdscr.respond_to?(:nodelay?) ? stdscr.nodelay? : false
    bytes = []
    deadline = Time.now + (timeout_ms / 1000.0)

    stdscr.nodelay = true
    while Time.now < deadline
      ch = stdscr.getch
      if ch.nil?
        sleep_ms(5)
        next
      end

      bytes.concat(ch.is_a?(String) ? ch.bytes : [ch])
      next if bytes.empty?
      next unless bytes[0] == 27

      final = bytes[-1]
      break if final.is_a?(Integer) && final >= 0x40 && final <= 0x7e
    end

    return nil if bytes.empty?

    bytes.pack("C*")
  ensure
    stdscr.nodelay = prev
  end

  def sleep_ms(ms)
    if Curses.respond_to?(:napms)
      Curses.napms(ms)
    else
      sleep(ms.to_f / 1000.0)
    end
  end

  def disable_enhanced_keyboard_input
    return unless $stdout.tty?

    # Pop keyboard mode stack once.
    $stdout.write("\e[<u")
    $stdout.flush
  rescue StandardError
    nil
  end
end

KeyProbe.new.run

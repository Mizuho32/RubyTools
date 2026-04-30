#!/usr/bin/env ruby
# frozen_string_literal: true

require "io/console"

class RawKeyProbe
  CSI_FINAL_MIN = 0x40
  CSI_FINAL_MAX = 0x7e

  def run
    print_banner

    STDIN.raw do |io|
      enable_enhanced_keyboard_input
      buffer = +"".b

      loop do
        wait = IO.select([io], nil, nil, 0.2)
        next unless wait

        chunk = io.read_nonblock(1024, exception: false)
        next if chunk == :wait_readable || chunk.nil? || chunk.empty?

        buffer << chunk.b
        events = drain_events(buffer)
        events.each do |event|
          quit = print_event(event)
          return if quit
        end
      end
    ensure
      disable_enhanced_keyboard_input
    end
  end

  private

  def print_banner
    puts "Raw Key Probe (no curses)"
    puts "- q or Ctrl+C: quit"
    puts "- Shows raw bytes and decoded ESC/CSI sequences"
    puts ""
  end

  def enable_enhanced_keyboard_input
    return unless $stdout.tty?

    # Push keyboard mode, enable disambiguate + event types + all keys,
    # then query current flags.
    $stdout.write("\e[>1u\e[=11;1u\e[?u")
    $stdout.flush
  end

  def disable_enhanced_keyboard_input
    return unless $stdout.tty?

    $stdout.write("\e[<u")
    $stdout.flush
  end

  def drain_events(buffer)
    events = []

    while !buffer.empty?
      if buffer.getbyte(0) == 27
        seq = extract_escape_sequence(buffer)
        break unless seq

        events << [:escape, seq]
        next
      end

      byte = buffer.getbyte(0)
      buffer.slice!(0)
      events << [:byte, byte]
    end

    events
  end

  def extract_escape_sequence(buffer)
    return nil if buffer.bytesize < 2

    second = buffer.getbyte(1)
    if second == 91 # CSI: ESC [
      i = 2
      while i < buffer.bytesize
        b = buffer.getbyte(i)
        if b >= CSI_FINAL_MIN && b <= CSI_FINAL_MAX
          return buffer.slice!(0, i + 1)
        end
        i += 1
      end
      return nil
    end

    if second == 79 # SS3: ESC O
      return nil if buffer.bytesize < 3

      return buffer.slice!(0, 3)
    end

    # ESC + single byte fallback (e.g. Alt+key legacy)
    return nil if buffer.bytesize < 2

    buffer.slice!(0, 2)
  end

  def print_event(event)
    type, payload = event

    case type
    when :byte
      byte = payload
      puts format("BYTE  0x%02X (%d)", byte, byte)
      return true if byte == 3 # Ctrl+C
      return true if byte == "q".ord
    when :escape
      seq = payload
      puts "ESC   bytes=#{seq.bytes.inspect} str=#{seq.inspect}"
      decoded = decode_escape(seq)
      puts "      decoded=#{decoded}" if decoded
    end

    false
  end

  def decode_escape(seq)
    if (m = seq.match(/^\e\[\?(\d+)u$/))
      return "kitty_kbd_reply flags=#{m[1]}"
    end

    if (m = seq.match(/^\e\[(\d+)(?:;(\d+)(?::(\d+))?)?u$/))
      key_code = m[1].to_i
      mod_value = (m[2] || "1").to_i
      event_value = (m[3] || "1").to_i
      action = { 1 => :press, 2 => :repeat, 3 => :release }[event_value] || :press
      mask = [mod_value - 1, 0].max
      mods = []
      mods << :shift if (mask & 0b001) != 0
      mods << :alt if (mask & 0b010) != 0
      mods << :ctrl if (mask & 0b100) != 0
      return "csi_u key=#{key_code} mods=#{mods.inspect} action=#{action}"
    end

    if (m = seq.match(/^\e\[(?:1;(\d+))?([ABCD])$/))
      key = { "A" => :up, "B" => :down, "C" => :right, "D" => :left }[m[2]]
      mod_value = (m[1] || "1").to_i
      mask = [mod_value - 1, 0].max
      mods = []
      mods << :shift if (mask & 0b001) != 0
      mods << :alt if (mask & 0b010) != 0
      mods << :ctrl if (mask & 0b100) != 0
      return "csi_arrow key=#{key} mods=#{mods.inspect}"
    end

    if (m = seq.match(/^\eO([ABCD])$/))
      key = { "A" => :up, "B" => :down, "C" => :right, "D" => :left }[m[1]]
      return "ss3_arrow key=#{key}"
    end

    nil
  end
end

RawKeyProbe.new.run

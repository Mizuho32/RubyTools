# frozen_string_literal: true

module WiFiKeyboard
  class InputDecoder
    def initialize(debug_logger: nil)
      @debug_logger = debug_logger
    end

    def key_code(ch)
      ch.is_a?(String) ? ch.ord : ch
    end

    def read_escape_event(raw, stdscr)
      bytes = escape_payload_bytes(raw)
      bytes.concat(read_escape_tail_bytes(stdscr)) unless escape_sequence_complete?(bytes)
      return nil if bytes.empty?

      event = decode_escape_event(bytes)
      debug("decoder.escape_event payload=#{bytes.inspect} event=#{event.inspect}")
      event
    end

    def consume_escape_sequence(stdscr)
      consumed = read_escape_tail_bytes(stdscr)
      debug("decoder.consume_escape payload=#{consumed.inspect}")
      !consumed.empty?
    end

    private

    def debug(msg)
      return unless @debug_logger

      @debug_logger.call(msg)
    rescue StandardError
      nil
    end

    def escape_payload_bytes(raw)
      return [] if raw.nil?

      if raw.is_a?(String)
        bytes = raw.bytes
        return [] unless bytes.first == 27

        return bytes[1..] || []
      end

      raw == 27 ? [] : []
    end

    def escape_sequence_complete?(bytes)
      return false if bytes.empty?

      final = bytes[-1]
      final.is_a?(Integer) && final >= 0x40 && final <= 0x7e
    end

    def read_escape_tail_bytes(stdscr)
      prev = stdscr.respond_to?(:nodelay?) ? stdscr.nodelay? : false
      bytes = []
      idle_polls = 0

      stdscr.nodelay = true
      while idle_polls < 20
        nxt = stdscr.getch
        if nxt.nil?
          idle_polls += 1
          sleep_ms(5)
          next
        end

        idle_polls = 0
        code = key_code(nxt)
        bytes << code
        break if code.is_a?(Integer) && code >= 0x40 && code <= 0x7e
      end
      bytes
    ensure
      stdscr.nodelay = prev
    end

    def sleep_ms(ms)
      if defined?(Curses) && Curses.respond_to?(:napms)
        Curses.napms(ms)
      else
        sleep(ms.to_f / 1000.0)
      end
    end

    def decode_escape_event(bytes)
      return nil if bytes.empty?
      return nil unless bytes[0] == 91 # '[' => CSI

      final = bytes[-1]
      return nil unless final.is_a?(Integer) && final >= 0x40 && final <= 0x7e

      param_str = bytes[1..-2].pack("C*")
      case final.chr
      when "A", "B", "C", "D"
        decode_legacy_arrow_event(final.chr, param_str)
      when "u"
        decode_csi_u_event(param_str)
      else
        nil
      end
    rescue StandardError
      nil
    end

    def decode_legacy_arrow_event(final_char, param_str)
      fields = param_str.split(";")
      mod_value = fields.length >= 2 ? fields[1].to_i : 1
      key = {
        "A" => :arrow_up,
        "B" => :arrow_down,
        "C" => :arrow_right,
        "D" => :arrow_left,
      }[final_char]
      return nil unless key

      {
        key: key,
        action: :down,
        mods: decode_modifiers(mod_value),
      }
    end

    def decode_csi_u_event(param_str)
      fields = param_str.split(";")
      return nil if fields.empty?

      key_code = fields[0].split(":").first.to_i
      mod_field = fields[1]
      mod_value = mod_field ? mod_field.split(":").first.to_i : 1
      event_value = if mod_field && mod_field.include?(":")
                      mod_field.split(":", 2)[1].to_i
                    elsif fields[2]
                      fields[2].to_i
                    else
                      1
                    end
      action = { 1 => :down, 2 => :repeat, 3 => :up }[event_value] || :down
      key = csi_u_key_symbol(key_code)
      return nil unless key

      {
        key: key,
        action: action,
        mods: decode_modifiers(mod_value),
      }
    end

    def csi_u_key_symbol(code)
      case code
      when 57441, 57447 then :shift
      when 57442, 57448 then :ctrl
      when 57443, 57449 then :alt
      when 57358 then :caps_lock
      when 1 then :arrow_up
      when 2 then :arrow_down
      when 3 then :arrow_right
      when 4 then :arrow_left
      else
        nil
      end
    end

    def decode_modifiers(mod_value)
      mask = [mod_value.to_i - 1, 0].max
      {
        shift: (mask & 0b0000_0001) != 0,
        alt: (mask & 0b0000_0010) != 0,
        ctrl: (mask & 0b0000_0100) != 0,
      }
    end
  end
end
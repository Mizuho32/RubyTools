# frozen_string_literal: true

require "curses"
require "unicode/display_width"
require_relative "client"
require_relative "input_decoder"

module WiFiKeyboard
  class TUI
    KEY_CTRL_C = 3
    KEY_CTRL_J = 10
    KEY_CTRL_L = 12
    KEY_CTRL_S = 19
    KEY_CR = 13
    KEY_ESC = 27

    ANDROID = {
      enter: 13,
      arrow_left: 37,
      arrow_up: 38,
      arrow_right: 39,
      arrow_down: 40,
      shift_left: 59,
      alt_left: 57,
      ctrl_left: 113,
      dpad_center: 23,
      menu: 82,
      search: 84,
      back: 4,
      volume_down: 25,
      volume_up: 24,
    }.freeze

    def initialize(client)
      @client = client
      @mode = :submit
      @status = :connecting
      @lines = [+""]
      @row = 0
      @col = 0
      @ignore_printable_until = Time.at(0)
      @debug_enabled = ENV["WIFIKEYBOARD_DEBUG"] == "1"
      @mb_buf = "".b  # accumulator for multibyte UTF-8 sequences (ASCII-8BIT)
      @input_decoder = InputDecoder.new(debug_logger: method(:debug_log))
    end

    def run
      begin
        Curses.setlocale(Curses::LC_ALL, "")
      rescue StandardError
      end

      Curses.init_screen
      Curses.start_color
      Curses.noecho
      Curses.cbreak
      Curses.stdscr.keypad(true)
      Curses.stdscr.nodelay = false

      Curses.init_pair(1, Curses::COLOR_BLACK, Curses::COLOR_GREEN)
      Curses.init_pair(2, Curses::COLOR_BLACK, Curses::COLOR_RED)
      Curses.init_pair(3, Curses::COLOR_BLACK, Curses::COLOR_YELLOW)
      Curses.init_pair(4, Curses::COLOR_WHITE, Curses::COLOR_BLUE)
      Curses.init_pair(5, Curses::COLOR_WHITE, Curses::COLOR_BLACK)

      enable_enhanced_keyboard_input

      @status = @client.ping

      loop do
        draw
        raw = Curses.stdscr.getch
        break if handle_key(raw) == :quit
      end
    ensure
      disable_enhanced_keyboard_input
      @client.close if @client.respond_to?(:close)
      Curses.close_screen
    end

    private

    def draw
      rows = Curses.lines
      cols = Curses.cols

      draw_status_bar(cols)
      draw_input_area(rows, cols)
      draw_help_bar(rows, cols)

      text_rows = rows - 2
      visible_row = [@row, text_rows - 1].min
      cursor_col = visual_col_for_index(current_line, @col).clamp(0, [cols - 1, 0].max)
      Curses.stdscr.setpos(1 + visible_row, cursor_col)
      Curses.stdscr.refresh
    end

    def draw_status_bar(cols)
      mode_label = @mode == :submit ? "Submit" : "Direct"
      status_str = case @status
                   when :connected then "Connected"
                   when :failure then "No connection"
                   when :problem then "Not typing"
                   when :multi then "Multiple input"
                   else "Connecting..."
                   end
      bar = "[#{status_str}] #{@client.host}:#{@client.port}  [#{mode_label} mode]"
      bar = bar.ljust(cols)[0, cols]
      Curses.stdscr.setpos(0, 0)
      Curses.stdscr.attron(Curses.color_pair(4)) { Curses.stdscr.addstr(bar) }
    end

    def draw_input_area(rows, cols)
      text_rows = rows - 2
      scroll = [@row - text_rows + 1, 0].max
      (0...text_rows).each do |r|
        Curses.stdscr.setpos(1 + r, 0)
        line_idx = scroll + r
        text = line_idx < @lines.size ? render_for_width(@lines[line_idx], cols) : (" " * cols)
        Curses.stdscr.addstr(text)
      end
    end

    def draw_help_bar(rows, cols)
      help = if @mode == :submit
               " ^S:Submit  Enter:↵  F4:Direct  ^L:Clear  ^C:Quit "
             else
               " F4:Submit  F5:Back  F1:Center  F2:Menu  F9/F10:Vol  ^C:Quit "
             end
      help = help.ljust(cols)[0, cols]
      Curses.stdscr.setpos(rows - 1, 0)
      Curses.stdscr.attron(Curses.color_pair(5)) { Curses.stdscr.addstr(help) }
    end

    def key_code(ch)
      @input_decoder.key_code(ch)
    end

    def handle_key(raw)
      code = key_code(raw)
      debug_log("tui.getch mode=#{@mode} raw_class=#{raw.class} raw=#{raw.inspect} normalized=#{code.inspect}")
      return handle_submit_mode(raw, code) if @mode == :submit

      handle_direct_mode(raw, code)
    end

    def handle_submit_mode(raw, code)
      # code >= 128 && < 256: raw byte of a multibyte UTF-8 sequence.
      # Anything else (special key constants, control chars) flushes the accumulator.
      unless code.is_a?(Integer) && code >= 128 && code < 256
        @mb_buf.clear
      end

      case code
      when KEY_CTRL_C
        return :quit
      when KEY_CTRL_S, Curses::KEY_ENTER
        do_submit
      when KEY_CTRL_L
        @lines = [+""]
        @row = 0
        @col = 0
      when Curses::KEY_F4
        @mode = :direct
      when Curses::KEY_LEFT
        move_cursor(-1, 0)
      when Curses::KEY_RIGHT
        move_cursor(1, 0)
      when Curses::KEY_UP
        move_cursor(0, -1)
      when Curses::KEY_DOWN
        move_cursor(0, 1)
      when Curses::KEY_BACKSPACE, 127, 8
        delete_char_before
      when Curses::KEY_DC
        delete_char_after
      when KEY_CR, KEY_CTRL_J
        insert_newline
      when 32..127
        # Plain printable ASCII — raw may be String or Integer
        insert_text(raw.is_a?(String) ? raw : raw.chr(Encoding::UTF_8))
      when 128..255
        # Raw byte of a multibyte UTF-8 sequence (getch returns Integer on Linux)
        @mb_buf << code
        attempt = @mb_buf.dup.force_encoding(Encoding::UTF_8)
        if attempt.valid_encoding?
          debug_log("tui.mb_insert buf=#{@mb_buf.bytes.inspect} char=#{attempt.inspect}")
          insert_text(attempt)
          @mb_buf.clear
        end
        # else: incomplete sequence, keep accumulating
      end
      nil
    end

    def handle_direct_mode(raw, code)
      case code
      when KEY_CTRL_C
        return :quit
      when Curses::KEY_F4
        @mode = :submit
      when KEY_ESC
        event = @input_decoder.read_escape_event(raw, Curses.stdscr)
        if event
          handle_direct_enhanced_event(event)
        else
          consumed_any = @input_decoder.consume_escape_sequence(Curses.stdscr)
          @ignore_printable_until = Time.now + 0.2 if consumed_any
        end
      when KEY_CR, KEY_CTRL_J, Curses::KEY_ENTER
        send_keycode_safe(ANDROID[:enter])
      when Curses::KEY_LEFT
        send_keycode_safe(ANDROID[:arrow_left])
      when Curses::KEY_RIGHT
        send_keycode_safe(ANDROID[:arrow_right])
      when Curses::KEY_UP
        send_keycode_safe(ANDROID[:arrow_up])
      when Curses::KEY_DOWN
        send_keycode_safe(ANDROID[:arrow_down])
      when Curses::KEY_F1
        send_keycode_safe(ANDROID[:dpad_center])
      when Curses::KEY_F2
        send_keycode_safe(ANDROID[:menu])
      when Curses::KEY_F3
        send_keycode_safe(ANDROID[:search])
      when Curses::KEY_F5
        send_keycode_safe(ANDROID[:back])
      when Curses::KEY_F9
        send_keycode_safe(ANDROID[:volume_down])
      when Curses::KEY_F10
        send_keycode_safe(ANDROID[:volume_up])
      when Curses::KEY_BACKSPACE, 127, 8
        send_keycode_safe(8)
      when Curses::KEY_DC
        send_keycode_safe(46)
      else
        if code >= 32 && code < 256
          if Time.now < @ignore_printable_until
            debug_log("tui.drop_printable_guard code=#{code}")
          else
            send_char_safe(code)
          end
        end
      end
      nil
    end

    def current_line
      @lines[@row] ||= +""
    end

    def insert_text(text)
      s = text.to_s
      return if s.empty?

      # curses may return strings tagged as ASCII-8BIT whose bytes are already
      # valid UTF-8.  Transcoding via encode() would misinterpret them as
      # Latin-1 and corrupt multibyte characters (e.g. Japanese).
      # Reinterpret raw bytes as UTF-8 instead.
      unless s.encoding == Encoding::UTF_8
        s = s.dup.force_encoding(Encoding::UTF_8)
      end
      return unless s.valid_encoding?

      @lines[@row].insert(@col, s)
      @col += s.length
    end

    def insert_newline
      tail = current_line.slice!(@col..)
      @lines.insert(@row + 1, tail || +"")
      @row += 1
      @col = 0
    end

    def delete_char_before
      if @col > 0
        current_line.slice!(@col - 1)
        @col -= 1
      elsif @row > 0
        prev = @lines[@row - 1]
        @col = prev.length
        @lines[@row - 1] = prev + @lines.delete_at(@row)
        @row -= 1
      end
    end

    def delete_char_after
      if @col < current_line.length
        current_line.slice!(@col)
      elsif @row < @lines.size - 1
        @lines[@row] += @lines.delete_at(@row + 1)
      end
    end

    def move_cursor(dcol, drow)
      @row = (@row + drow).clamp(0, @lines.size - 1)
      @col = @col.clamp(0, current_line.length)
      @col = (@col + dcol).clamp(0, current_line.length)
    end

    def do_submit
      text = @lines.join("\n")
      return if text.empty?

      ok = @client.submit(text)
      if ok
        @status = :connected
        @lines = [+""]
        @row = 0
        @col = 0
      end
    rescue WiFiKeyboard::ConnectionError
      @status = :failure
    end

    def send_keycode_safe(code)
      debug_log("tui.send_keycode code=#{code}")
      ok = @client.send_keycode(code)
      @status = :connected if ok
    rescue WiFiKeyboard::ConnectionError
      @status = :failure
    end

    def send_key_action_safe(code, action)
      packet = case action
               when :down then "D#{code},"
               when :up then "U#{code},"
               when :repeat then "D#{code},"
               else return
               end
      debug_log("tui.send_key_action code=#{code} action=#{action}")
      ok = @client.send_key(packet)
      @status = :connected if ok
    rescue WiFiKeyboard::ConnectionError
      @status = :failure
    end

    def send_char_safe(code)
      debug_log("tui.send_char code=#{code} char=#{code.chr(Encoding::UTF_8).inspect rescue '<?>'}")
      ok = @client.send_key("C#{code},")
      @status = :connected if ok
    rescue WiFiKeyboard::ConnectionError
      @status = :failure
    end

    def handle_direct_enhanced_event(event)
      key = event[:key]
      action = event[:action] || :down
      mods = event[:mods] || {}

      case key
      when :arrow_up
        send_key_action_with_mods(ANDROID[:arrow_up], action, mods)
      when :arrow_down
        send_key_action_with_mods(ANDROID[:arrow_down], action, mods)
      when :arrow_left
        send_key_action_with_mods(ANDROID[:arrow_left], action, mods)
      when :arrow_right
        send_key_action_with_mods(ANDROID[:arrow_right], action, mods)
      when :shift
        send_key_action_safe(ANDROID[:shift_left], action)
      when :alt
        send_key_action_safe(ANDROID[:alt_left], action)
      when :ctrl
        send_key_action_safe(ANDROID[:ctrl_left], action)
      else
        nil
      end
    end

    def send_key_action_with_mods(keycode, action, mods)
      mod_codes = []
      mod_codes << ANDROID[:shift_left] if mods[:shift]
      mod_codes << ANDROID[:alt_left] if mods[:alt]
      mod_codes << ANDROID[:ctrl_left] if mods[:ctrl]

      if action == :up
        send_key_action_safe(keycode, :up)
        mod_codes.reverse_each { |code| send_key_action_safe(code, :up) }
      else
        mod_codes.each { |code| send_key_action_safe(code, :down) }
        if action == :repeat
          send_key_action_safe(keycode, :down)
        else
          send_key_action_safe(keycode, :down)
          send_key_action_safe(keycode, :up)
        end
        mod_codes.reverse_each { |code| send_key_action_safe(code, :up) }
      end
    end

    def enable_enhanced_keyboard_input
      return unless $stdout.tty?

      # Push keyboard mode stack and enable:
      # - disambiguate escape codes (0b1)
      # - report event types (0b10)
      # - report all keys as escape codes (0b1000)
      # flags = 11
      $stdout.write("\e[>1u\e[=11;1u")
      $stdout.flush
    rescue StandardError => e
      debug_log("tui.enable_enhanced_input error=#{e.class}: #{e.message}")
    end

    def disable_enhanced_keyboard_input
      return unless $stdout.tty?

      # Pop keyboard mode stack once.
      $stdout.write("\e[<u")
      $stdout.flush
    rescue StandardError => e
      debug_log("tui.disable_enhanced_input error=#{e.class}: #{e.message}")
    end

    def debug_log(msg)
      return unless @debug_enabled

      line = "#{Time.now.strftime('%Y-%m-%d %H:%M:%S.%L')} [TUI] #{msg}\n"
      File.open(ENV.fetch("WIFIKEYBOARD_DEBUG_LOG", "/tmp/wifikeyboard_debug.log"), "a") { |f| f.write(line) }
      $stderr.write(line) if ENV["WIFIKEYBOARD_DEBUG_STDERR"] == "1"
    rescue
      nil
    end

    def printable_text?(s)
      return false unless s.valid_encoding?
      return false if s.empty?

      !s.match?(/\p{Cntrl}/)
    end

    def render_for_width(text, cols)
      out = +""
      width = 0

      text.each_char do |ch|
        w = [Unicode::DisplayWidth.of(ch, ambiguous: 1), 1].max
        break if width + w > cols

        out << ch
        width += w
      end

      out << (" " * [cols - width, 0].max)
      out
    end

    def visual_col_for_index(text, index)
      col = 0
      text.each_char.with_index do |ch, i|
        break if i >= index

        col += [Unicode::DisplayWidth.of(ch, ambiguous: 1), 1].max
      end
      col
    end
  end
end

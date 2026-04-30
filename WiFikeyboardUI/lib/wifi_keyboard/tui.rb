# frozen_string_literal: true

require "curses"
require_relative "client"

module WiFiKeyboard
  class TUI
    # Special key codes from curses
    KEY_CTRL_C        = 3
    KEY_CTRL_J        = 10   # Ctrl+J / LF
    KEY_CTRL_L        = 12
    KEY_CTRL_S        = 19   # Submit fallback (reliable across terminals)
    KEY_CR            = 13   # plain Enter (CR)
    KEY_ESC           = 27

    # Android key codes (WiFiKeyboard protocol)
    ANDROID = {
      enter:        13,
      arrow_left:   37,
      arrow_up:     38,
      arrow_right:  39,
      arrow_down:   40,
      dpad_center:  23,
      menu:         82,
      search:       84,
      back:          4,
      volume_down:  25,
      volume_up:    24,
    }.freeze

    def initialize(client)
      @client  = client
      @mode    = :submit   # :submit | :direct
      @status  = :connecting
      @lines   = [+""]    # buffer: array of strings (each line)
      @row     = 0        # cursor row in @lines
      @col     = 0        # cursor col in current line
      @ignore_printable_until = Time.at(0)
    end

    def run
      Curses.init_screen
      Curses.start_color
      Curses.noecho
      Curses.cbreak
      Curses.stdscr.keypad(true)
      Curses.stdscr.nodelay = false
      Curses.init_pair(1, Curses::COLOR_BLACK, Curses::COLOR_GREEN)  # connected
      Curses.init_pair(2, Curses::COLOR_BLACK, Curses::COLOR_RED)    # failure
      Curses.init_pair(3, Curses::COLOR_BLACK, Curses::COLOR_YELLOW) # connecting
      Curses.init_pair(4, Curses::COLOR_WHITE, Curses::COLOR_BLUE)   # status bar
      Curses.init_pair(5, Curses::COLOR_WHITE, Curses::COLOR_BLACK)  # help bar

      # One-shot connectivity check at startup. Avoid periodic network traffic
      # so user key sends are never interleaved with background requests.
      @status = @client.ping

      loop do
        draw
        ch = Curses.stdscr.getch
        break if handle_key(ch) == :quit
      end
    ensure
      @client.close if @client.respond_to?(:close)
      Curses.close_screen
    end

    private

    # ── Drawing ────────────────────────────────────────────────────────────────

    def draw
      rows = Curses.lines
      cols = Curses.cols

      draw_status_bar(cols)
      draw_input_area(rows, cols)
      draw_help_bar(rows, cols)

      # Position cursor
      text_rows = rows - 2
      visible_row = [@row, text_rows - 1].min
      Curses.stdscr.setpos(1 + visible_row, @col)
      Curses.stdscr.refresh
    end

    def draw_status_bar(cols)
      mode_label = @mode == :submit ? "Submit" : "Direct"
      status_str = case @status
                   when :connected   then "Connected"
                   when :failure     then "No connection"
                   when :problem     then "Not typing"
                   when :multi       then "Multiple input"
                   else                   "Connecting..."
                   end
      pair = case @status
             when :connected then 1
             when :failure   then 2
             else                 3
             end
      bar = "[#{status_str}] #{@client.host}:#{@client.port}  [#{mode_label} mode]"
      bar = bar.ljust(cols)[0, cols]
      Curses.stdscr.setpos(0, 0)
      Curses.stdscr.attron(Curses.color_pair(4)) { Curses.stdscr.addstr(bar) }
    end

    def draw_input_area(rows, cols)
      text_rows = rows - 2
      # Determine scroll offset so cursor is visible
      scroll = [@row - text_rows + 1, 0].max
      (0...text_rows).each do |r|
        Curses.stdscr.setpos(1 + r, 0)
        line_idx = scroll + r
        text = line_idx < @lines.size ? @lines[line_idx][0, cols].ljust(cols) : " " * cols
        Curses.stdscr.addstr(text)
      end
    end

    def draw_help_bar(rows, cols)
      help = if @mode == :submit
               " ^Enter:Submit  Enter:↵  F4:Direct  ^L:Clear  ^C:Quit "
             else
               " F4:Submit  Esc/F5:Back  F1:Center  F2:Menu  F9/F10:Vol  ^C:Quit "
             end
      help = help.ljust(cols)[0, cols]
      Curses.stdscr.setpos(rows - 1, 0)
      Curses.stdscr.attron(Curses.color_pair(5)) { Curses.stdscr.addstr(help) }
    end

    # ── Key handling ────────────────────────────────────────────────────────────

    # getch returns String for regular/control chars, Integer for special keys.
    # Normalize everything to Integer so all `when` branches work uniformly.
    def normalize_key(ch)
      ch.is_a?(String) ? ch.ord : ch
    end

    def handle_key(ch)
      k = normalize_key(ch)
      debug_log("tui.getch mode=#{@mode} raw_class=#{ch.class} raw=#{ch.inspect} normalized=#{k.inspect}")
      if @mode == :submit
        handle_submit_mode(k)
      else
        handle_direct_mode(k)
      end
    end

    def handle_submit_mode(ch)
      case ch
      when KEY_CTRL_C
        return :quit

        when KEY_CTRL_S,      # Ctrl+S — submit on all terminals
             Curses::KEY_ENTER # numpad Enter
        do_submit

      when KEY_CTRL_L

          # Avoid losing payload while a previous submit is still in flight.
          if @submit_thread&.alive?
            @status = :connecting
            return
          end
        @lines = [+""]
        @row = 0
        @col = 0

      when Curses::KEY_F4
        @mode = :direct
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

      when KEY_CR, KEY_CTRL_J  # Enter / LF — insert newline locally
        insert_newline

      else
        insert_char(ch) if ch >= 32 && ch < 256
      end
      nil
    end

    def handle_direct_mode(ch)
      case ch
      when KEY_CTRL_C
        return :quit

      when Curses::KEY_F4
        @mode = :submit

      when KEY_ESC
        # Some terminals emit control replies like ESC [ ... c.
        # Always consume/drop ESC sequences in Direct mode to avoid
        # trailing bytes (often 'c') being mistaken as user input.
        consume_escape_sequence

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
        send_keycode_safe(67)  # Android KEYCODE_DEL

      when Curses::KEY_DC
        send_keycode_safe(67)  # Treat Delete as DEL too

      else
        if ch >= 32 && ch < 256
          if Time.now < @ignore_printable_until
            debug_log("tui.drop_printable_guard code=#{ch}")
          else
            send_char_safe(ch)
          end
        end
      end
      nil
    end

    # ── Buffer helpers ──────────────────────────────────────────────────────────

    def current_line
      @lines[@row] ||= +""
    end

    def insert_char(code)
      c = code.chr(Encoding::UTF_8) rescue return
      @lines[@row].insert(@col, c)
      @col += 1
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
      new_row = (@row + drow).clamp(0, @lines.size - 1)
      @row = new_row
      @col = @col.clamp(0, current_line.length)
      new_col = (@col + dcol).clamp(0, current_line.length)
      @col = new_col
    end

    # ── Actions ─────────────────────────────────────────────────────────────────

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

    def send_char_safe(code)
      debug_log("tui.send_char code=#{code} char=#{code.chr(Encoding::UTF_8).inspect rescue '<?>'}")
      ok = @client.send_key("C#{code},")
      @status = :connected if ok
    rescue WiFiKeyboard::ConnectionError
      @status = :failure
    end

    def consume_escape_sequence
      stdscr = Curses.stdscr
      prev = stdscr.nodelay?
      consumed_any = false
      idle_polls = 0
      consumed = []

      stdscr.nodelay = true
      # Wait briefly for delayed bytes; terminal replies may arrive a bit later.
      while idle_polls < 20
        nxt = stdscr.getch
        if nxt.nil?
          idle_polls += 1
          Curses.napms(5)
          next
        end
        idle_polls = 0

        consumed_any = true
        code = normalize_key(nxt)
        consumed << code
        # ANSI control sequence final byte range.
        break if code.is_a?(Integer) && code >= 0x40 && code <= 0x7e
      end

      debug_log("tui.consume_escape consumed_any=#{consumed_any} bytes=#{consumed.inspect}")
      # Some terminals flush trailing printable bytes slightly later.
      @ignore_printable_until = Time.now + 0.2 if consumed_any

      consumed_any
    ensure
      stdscr.nodelay = prev
    end

    def debug_log(msg)
      line = "#{Time.now.strftime('%Y-%m-%d %H:%M:%S.%L')} [TUI] #{msg}\n"
      File.open(ENV.fetch("WIFIKEYBOARD_DEBUG_LOG", "/tmp/wifikeyboard_debug.log"), "a") { |f| f.write(line) }
      $stderr.write(line) if ENV["WIFIKEYBOARD_DEBUG_STDERR"] == "1"
    rescue
      nil
    end

  end
end

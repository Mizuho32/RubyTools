# TUI of WiFikeyboard

## Original UI
https://raw.githubusercontent.com/IvanVolosyuk/wifikeyboard/refs/heads/master/html/key.html

## Overview
Ruby/curses TUI client that connects to the WiFiKeyboard HTTP server running on Android.

**Default mode is Submit** — type locally, then send the whole text at once.
Press F4 to toggle into Direct mode where every keystroke is sent immediately.

## Usage
```
ruby bin/key.rb <host:port>
# e.g.
ruby bin/key.rb 192.168.0.10:7777
# DEBUG WIFIKEYBOARD_DEBUG=1
```

## Layout
```
[Status: Connected | 192.168.0.10:7777                        ]  ← status bar
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   text input area (scrollable, multi-line)                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
[Ctrl+S:Submit  Enter:↵  F4:Direct  Ctrl+L:Clear  ^C:Quit ]  ← help bar
```

## Key Bindings

### Submit Mode (default)
| Key | Action |
|---|---|
| `Enter` | Insert newline locally |
| `Ctrl+S` | POST /form — send buffer to Android, clear |
| `F4` | Switch to Direct mode |
| `←` `→` `↑` `↓` | Move cursor locally |
| `Backspace` / `Delete` | Delete locally |
| `Ctrl+L` | Clear input buffer |
| `Ctrl+C` | Quit |

### Direct Mode (F4 to toggle)
| Key | Action |
|---|---|
| Printable chars | Send char code via /key immediately |
| `Enter` | Send keycode 13 via /key |
| `←` `→` `↑` `↓` | Send DPAD arrow keycodes (37–40) |
| `F1` | DPAD Center (keycode 23) |
| `F2` | Menu (keycode 82) |
| `F3` | Search (keycode 84) |
| `F5` | BACK (keycode 4) |
| `F9` | Volume Down (keycode 25) |
| `F10` | Volume Up (keycode 24) |
| `F4` | Switch back to Submit mode |
| `Ctrl+C` | Quit |

## HTTP Endpoints (WiFiKeyboard server)
| Method | Path | Purpose |
|---|---|---|
| POST | /form | Submit text (raw body, no `text=` wrapper) |
| GET | /key?seq,data | Send key event (`C<code>` = char, `D<code>` = keydown) |
| GET | /text | Fetch current Android text field content |

## Files
- `bin/key.rb` — CLI entry point
- `lib/wifi_keyboard/client.rb` — Net::HTTP wrapper
- `lib/wifi_keyboard/tui.rb` — curses TUI

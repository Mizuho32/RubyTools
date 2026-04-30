#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "wifi_keyboard/client"
require "wifi_keyboard/tui"

trap("INT") { exit }

host_port = ARGV[0]
if host_port.nil? || host_port.empty?
  warn "Usage: #{File.basename($0)} <host:port>"
  warn "  e.g. #{File.basename($0)} 192.168.0.10:7777"
  exit 1
end

client = WiFiKeyboard::Client.new(host_port)
tui    = WiFiKeyboard::TUI.new(client)
tui.run

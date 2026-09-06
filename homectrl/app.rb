#!/usr/bin/env ruby
# frozen_string_literal: true

require "sinatra/base"
require "rack/cascade"
require "rack/handler/puma"
require_relative "lib/homectrl/config"
require_relative "lib/homectrl/plugin_loader"

# Depending on the rack/rackup gem versions loaded transitively, puma
# registers its handler under Rackup::Handler::Puma (rack 3 + rackup gem)
# rather than Rack::Handler::Puma.
puma_handler = defined?(Rackup::Handler::Puma) ? Rackup::Handler::Puma : Rack::Handler::Puma

root = __dir__
config = Homectrl::Config.load(File.join(root, "config.yaml"))
port = (ARGV[0] || config.port).to_i

plugins = Homectrl::PluginLoader.load_all(config.enabled_plugins, plugins_dir: File.join(root, "plugins"))

bg_threads = plugins.filter_map { |klass| klass.start_background(config) }

routed = plugins.select { |klass| klass < Sinatra::Base }
portal, main = routed.partition { |klass| klass.plugin_name == "portal" }

main_app = Rack::Cascade.new(main)
portal_app = Rack::Cascade.new(portal) unless portal.empty?

server_threads = [
  Thread.new { puma_handler.run(main_app, Host: config.bind, Port: port) }
]
if portal_app
  server_threads << Thread.new do
    puma_handler.run(portal_app, Host: config.portal_bind, Port: config.portal_port)
  end
end

trap("INT") { exit 0 }

puts "#{__FILE__} plugins loaded: #{plugins.map(&:plugin_name).join(', ')}"
puts "  main:   http://#{config.bind}:#{port}"
puts "  portal: http://#{config.portal_bind}:#{config.portal_port}/portal" if portal_app

# Only join the HTTP server threads: the process should keep running as long
# as those are up. A background plugin thread (e.g. vivaldi_suspend's D-Bus
# loop) may legitimately die on its own (it already logs via
# report_on_exception / its own rescue) without taking the whole server down.
server_threads.each(&:join)

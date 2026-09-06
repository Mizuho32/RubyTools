# frozen_string_literal: true

require "dbus"
require "json"
require_relative "../../lib/homectrl/plugin"

module Homectrl
  module Plugins
    # Listens on the D-Bus session bus for KWin "window minimized" notifications
    # and SIGSTOP/SIGCONTs process accordingly. No HTTP routes; background-only.
    # Ported as-is from the original share_tmux_copy/server.rb.
    class VivaldiSuspend
      include Homectrl::Plugin
      plugin_name "process_suspend"
      plugin_description "SIGSTOP/SIGCONT process when KWin reports it minimized"

      class KwinListener < DBus::Object
        dbus_interface "org.homectrl.Kwin" do
          dbus_method :notify, "in msg:s" do |msg|
            # like: {"minimizedChanged":"音量調節","minimized":false}
            data = JSON.parse(msg, symbolize_names: true)
            # puts data
            if data[:minimizedChanged]&.match?(/Vivaldi$/) then
              system(data[:minimized] ? "killall -SIGSTOP vivaldi" : "killall -SIGCONT vivaldi")
            elsif data[:minimizedChanged]&.match?(/^音量調節$/) then
              system(data[:minimized] ? "killall -SIGSTOP pavucontrol" : "killall -SIGCONT pavucontrol")
            end
          end
        end

        def initialize(path)
          super(path)
        end
      end

      def self.start_background(_config)
        Thread.new do
          bus = DBus::SessionBus.instance
          service = bus.request_service("org.homectrl.Kwin")
          service.export(KwinListener.new("/Kwin"))

          main = DBus::Main.new
          main << bus
          main.run
        rescue StandardError => e
          warn(e.message, e.backtrace.join("\n"))
        end
      end
    end
  end
end

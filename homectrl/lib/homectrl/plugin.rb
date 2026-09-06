# frozen_string_literal: true

module Homectrl
  # Mixin every plugin includes. Registers the class on load and gives it
  # two optional hooks: HTTP routes (the class can just be a Sinatra::Base
  # subclass and use the normal route DSL) and a background thread (for
  # things like the vivaldi_suspend D-Bus loop).
  module Plugin
    def self.included(base)
      base.extend(ClassMethods)
      Registry.register(base)
    end

    module ClassMethods
      def plugin_name(value = nil)
        @plugin_name = value if value
        @plugin_name || name.split("::").last
      end

      def plugin_description(value = nil)
        @plugin_description = value if value
        @plugin_description
      end

      # Override to run a background concern (dbus loop, watcher, ...).
      # Must return a Thread, or nil if this plugin has none.
      def start_background(_config)
        nil
      end
    end
  end

  module Registry
    def self.register(klass)
      list << klass unless list.include?(klass)
    end

    def self.list
      @list ||= []
    end
  end
end

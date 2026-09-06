# frozen_string_literal: true

require_relative "plugin"

module Homectrl
  module PluginLoader
    # Requires plugins/<name>/plugin.rb for each enabled name, in order.
    # Each required file is expected to include Homectrl::Plugin, which
    # registers it. Returns the full registry list.
    def self.load_all(enabled_names, plugins_dir:)
      enabled_names.each do |name|
        path = File.join(plugins_dir, name, "plugin.rb")
        raise "plugin not found: #{path}" unless File.exist?(path)

        require path
      end
      Registry.list
    end
  end
end

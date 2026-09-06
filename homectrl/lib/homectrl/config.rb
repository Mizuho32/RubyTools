# frozen_string_literal: true

require "yaml"

module Homectrl
  class Config
    REQUIRED_KEYS = %w[bind port plugins].freeze

    attr_reader :bind, :port, :portal_bind, :portal_port, :enabled_plugins

    def initialize(bind:, port:, plugins:, portal: {})
      @bind = bind
      @port = Integer(port)
      @enabled_plugins = Array(plugins)
      @portal_bind = portal.fetch("bind", "127.0.0.1")
      @portal_port = Integer(portal.fetch("port", 8080))
    end

    def self.load(path)
      raise ArgumentError, "config file not found: #{path}" unless File.exist?(path)

      raw = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
      raise ArgumentError, "config must be a YAML mapping" unless raw.is_a?(Hash)

      missing = REQUIRED_KEYS.reject { |key| raw.key?(key) }
      raise ArgumentError, "missing config keys: #{missing.join(", ")}" unless missing.empty?

      new(
        bind: raw["bind"],
        port: raw["port"],
        plugins: raw["plugins"],
        portal: raw["portal"] || {}
      )
    end
  end
end

# frozen_string_literal: true

require "yaml"

module WolUi
  class Config
    REQUIRED_KEYS = %w[machine_list_path broadcast_ip port].freeze

    attr_reader :machine_list_path, :broadcast_ip, :port

    def initialize(machine_list_path:, broadcast_ip:, port:)
      @machine_list_path = machine_list_path
      @broadcast_ip = broadcast_ip
      @port = Integer(port)
    end

    def self.load(path)
      raise ArgumentError, "config file not found: #{path}" unless File.exist?(path)

      raw = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
      raise ArgumentError, "config must be a YAML mapping" unless raw.is_a?(Hash)

      missing = REQUIRED_KEYS.reject { |key| raw.key?(key) }
      raise ArgumentError, "missing config keys: #{missing.join(", ")}" unless missing.empty?

      new(
        machine_list_path: raw["machine_list_path"],
        broadcast_ip: raw["broadcast_ip"],
        port: raw["port"]
      )
    end
  end
end

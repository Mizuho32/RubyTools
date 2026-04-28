# frozen_string_literal: true

require_relative "config"
require_relative "machine_parser"
require_relative "wol_sender"

module WolUi
  class CLI
    def self.run(config_path = "config.yaml")
      config = Config.load(config_path)
      machines = MachineParser.parse(config.machine_list_path)

      if machines.empty?
        warn "no valid machines found in #{config.machine_list_path}"
        return 1
      end

      print_machine_list(machines)
      machine = select_machine(machines)
      return 1 if machine.nil?

      print "Send WOL to #{machine.name}? [y/N]: "
      confirm = STDIN.gets.to_s.strip.downcase
      return 0 unless confirm == "y"

      WolSender.send_wol(mac: machine.mac, broadcast_ip: config.broadcast_ip, port: config.port)
      puts "WOL sent: #{machine.name} (#{machine.mac})"
      0
    rescue StandardError => e
      warn "error: #{e.message}"
      1
    end

    def self.print_machine_list(machines)
      machines.each_with_index do |machine, idx|
        puts format("[%d] %-20s %s", idx + 1, machine.name, machine.mac)
      end
    end

    def self.select_machine(machines)
      print "Select machine (number/name): "
      input = STDIN.gets.to_s.strip
      return nil if input.empty?

      number = Integer(input, exception: false)
      return machines[number - 1] unless number.nil?

      exact = machines.find { |machine| machine.name.casecmp?(input) }
      return exact unless exact.nil?

      matches = machines.select { |machine| machine.name.downcase.include?(input.downcase) }
      if matches.length == 1
        matches.first
      elsif matches.empty?
        warn "no machine matched: #{input}"
        nil
      else
        warn "multiple machines matched: #{matches.map(&:name).join(", ")}"
        nil
      end
    end
  end
end

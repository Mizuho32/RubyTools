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
      machines = select_machine(machines)
      return 1 if machines.nil?

      print "Send WOL to? [y/N]:\n#{machines.map{"#{_2+1}: #{_1.name}"}.join("\n")}\n>> "
      confirm = STDIN.gets.to_s.strip.downcase
      return 0 unless confirm == "y"

      machines.each{|machine, _|
        WolSender.send_wol(mac: machine.mac, broadcast_ip: config.broadcast_ip, port: config.port)
        puts "WOL sent: #{machine.name} (#{machine.mac})"
      }
      0
    rescue StandardError => e
      warn "error: #{e.message}\n#{e.backtrace.join("\n")}"
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

      #number = Integer(input, exception: false)
      #return machines[number - 1] unless number.nil?

      exact = machines.find { |machine| machine.name.casecmp?(input) }
      return exact unless exact.nil?

      matches = machines.each_with_index.select { |machine, idx| input.downcase.split(/[^a-z0-9]/).any?{ machine.name.downcase.include?(_1) || idx+1 == Integer(_1, exception: false) } }
      if matches.length == 1
        matches
      elsif matches.empty?
        warn "\nno machine matched: #{input}"
        nil
      else
        warn "\nmultiple machines matched!"#: #{matches.map(&:name).join(", ")}"
        matches
      end
    end
  end
end

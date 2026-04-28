# frozen_string_literal: true

require "socket"

module WolUi
  class WolSender
    def self.send_wol(mac:, broadcast_ip:, port:)
      packet = magic_packet(mac)

      socket = UDPSocket.new
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      socket.send(packet, 0, broadcast_ip, port)
    ensure
      socket&.close
    end

    def self.magic_packet(mac)
      bytes = mac.split(":").map { |hex| Integer(hex, 16) }
      ([0xFF] * 6 + bytes * 16).pack("C*")
    end
  end
end

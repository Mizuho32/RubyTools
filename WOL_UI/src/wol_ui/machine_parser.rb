# frozen_string_literal: true

require "cgi"

module WolUi
  Machine = Struct.new(:name, :mac, keyword_init: true)

  class MachineParser
    NAME_HEADERS = %w[name machine host hostname].freeze
    MAC_HEADERS = %w[mac macaddress mac_address].freeze
    MAC_CANDIDATE_REGEX = /(?:
      (?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}|
      (?:[0-9A-Fa-f]{4}\.){2}[0-9A-Fa-f]{4}|
      (?<![0-9A-Fa-f])[0-9A-Fa-f]{12}(?![0-9A-Fa-f])
    )/x.freeze

    def self.parse(path)
      raise ArgumentError, "machine list not found: #{path}" unless File.exist?(path)

      rows = markdown_rows(File.read(path))
      return [] if rows.empty?

      header = rows.first.map { |value| normalize_header(value) }
      name_idx = header_index(header, NAME_HEADERS)
      mac_idx = header_index(header, MAC_HEADERS)

      data_rows = rows.drop(1)
      data_rows.filter_map do |row|
        name, mac = extract_values(row, name_idx, mac_idx)
        next if name.nil? || name.empty? || mac.nil?

        Machine.new(name: name, mac: mac)
      end
    end

    def self.markdown_rows(text)
      text.lines.map(&:strip).select { |line| line.start_with?("|") }.filter_map do |line|
        next if separator_row?(line)

        cells = line.split("|")[1..-1]
        next if cells.nil? || cells.empty?

        cells.map { |cell| cell.strip }
      end
    end

    def self.separator_row?(line)
      line.match?(/^\|[\s:\-\|]+\|?$/)
    end

    def self.normalize_header(value)
      value.downcase.gsub(/[^a-z0-9]/, "")
    end

    def self.header_index(header, candidates)
      header.index { |name| candidates.include?(name) }
    end

    def self.extract_values(row, name_idx, mac_idx)
      name = safe_cell(row, name_idx)
      mac_raw = safe_cell(row, mac_idx)

      mac_raw ||= row.find { |value| !normalize_mac(value).nil? }
      name ||= row.find { |value| name_like?(value) && normalize_mac(value).nil? }

      [normalize_name(name), normalize_mac(mac_raw)]
    end

    def self.safe_cell(row, idx)
      return nil if idx.nil? || idx >= row.length

      row[idx]
    end

    def self.normalize_mac(raw)
      return nil if raw.nil?

      match = raw.to_s.match(MAC_CANDIDATE_REGEX)
      return nil if match.nil?

      hex = match[0].gsub(/[^0-9A-Fa-f]/, "").upcase
      return nil unless hex.length == 12

      hex.scan(/../).join(":")
    end

    def self.normalize_name(raw)
      return nil if raw.nil?

      text = raw.to_s
      text = CGI.unescapeHTML(text)
      text = text.gsub(/<[^>]+>/, " ")

      # Keep link text for markdown links.
      text = text.gsub(/\[([^\]]+)\]\([^\)]+\)/, "\\1")
      text = text.gsub(/`+/, "")

      # Remove MAC-like fragments and common label prefixes.
      text = text.gsub(MAC_CANDIDATE_REGEX, " ")
      text = text.gsub(/\b(?:name|machine|host|hostname)\s*[:：]\s*/i, "")

      # If extra notes are appended, prioritize the first machine-like segment.
      segment = text.split(/[;,|\/]/).map(&:strip).find { |part| name_like?(part) }
      candidate = (segment || text).strip
      candidate = candidate.split(/\s+(?:その他|etc\.?|note)\b/i).first.to_s.strip
      candidate = candidate.gsub(/\s+/, " ")

      return nil unless name_like?(candidate)

      candidate
    end

    def self.name_like?(raw)
      return false if raw.nil?

      text = raw.to_s
      text = text.gsub(/<[^>]+>/, " ")
      text = text.gsub(/\s+/, " ").strip
      return false if text.empty?

      # Accept names with spaces/hyphens/underscores, but require at least one letter/number.
      text.match?(/[\p{L}\p{N}]/) && !text.match?(MAC_CANDIDATE_REGEX)
    end
  end
end

#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "fileutils"
require "optparse"
require "sqlite3"

module NavidromeBackup
  class Error < StandardError; end

  Playlist = Struct.new(:id, :name, :song_count, :created_at, keyword_init: true)
  Track = Struct.new(:title, :album, :artist, :path, keyword_init: true)

  class CLI
    def initialize(argv)
      @argv = argv.dup
      @options = { tags: [] }
    end

    def run
      parser = build_parser
      parser.parse!(@argv)

      validate_options!(parser)

      exporter = Exporter.new(
        database_path: @options[:database_path],
        output_dir: @options[:output_dir],
        patterns: @argv,
        user_tags: @options[:tags]
      )

      exported_files = exporter.export
      puts "Exported #{exported_files.length} playlist(s):"
      exported_files.each { |path| puts "- #{path}" }
    rescue OptionParser::ParseError, Error => e
      warn e.message
      warn parser.to_s if parser
      exit 1
    end

    private

    def build_parser
      OptionParser.new do |opts|
        opts.banner = <<~BANNER
          Usage: bundle exec ruby backup_playlists.rb --db PATH --out DIR [--tag TAG] PATTERN [PATTERN...]

          Export playlists whose names include any of the given patterns.
        BANNER

        opts.on("--db PATH", "Path to Navidrome SQLite database") do |path|
          @options[:database_path] = path
        end

        opts.on("--out DIR", "Directory where markdown files will be written") do |dir|
          @options[:output_dir] = dir
        end

        opts.on("--tag TAG", "Obsidian tag to add to every exported file (repeatable)") do |tag|
          @options[:tags] << tag
        end
      end
    end

    def validate_options!(parser)
      raise Error, "Missing required option: --db" unless @options[:database_path]
      raise Error, "Missing required option: --out" unless @options[:output_dir]
      raise Error, "Provide at least one playlist name pattern." if @argv.empty?
      raise Error, "SQLite database not found: #{@options[:database_path]}" unless File.file?(@options[:database_path])

      parser
    end
  end

  class Exporter
    def initialize(database_path:, output_dir:, patterns:, user_tags:)
      @database_path = database_path
      @output_dir = output_dir
      @patterns = compile_patterns(patterns)
      @user_tags = user_tags
    end

    def export
      playlists = matching_playlists
      raise Error, "No playlists matched patterns: #{@patterns.join(', ')}" if playlists.empty?

      FileUtils.mkdir_p(@output_dir)

      playlists.map do |playlist|
        output_path = File.join(@output_dir, "#{safe_filename(playlist.name)}.md")
        File.write(output_path, render_playlist(playlist))
        output_path
      end
    ensure
      database.close if defined?(database) && database
    end

    private

    def matching_playlists
      rows = database.execute("SELECT id, name, song_count, created_at FROM playlist ORDER BY name")
      rows.filter_map do |id, name, song_count, created_at|
        next unless matches_patterns?(name)

        Playlist.new(id: id, name: name, song_count: song_count, created_at: created_at)
      end
    end

    def matches_patterns?(playlist_name)
      @patterns.any? do |pattern|
        case pattern[:type]
        when :regex
          pattern[:value].match?(playlist_name)
        else
          playlist_name.downcase.include?(pattern[:value])
        end
      end
    end

    def render_playlist(playlist)
      tracks = fetch_tracks(playlist.id)
      tags = (@user_tags.map { |tag| "##{normalize_tag(tag)}" } + ["#navidrome/#{normalize_tag_path(playlist.name)}"]).uniq

      lines = []
      lines << "# #{playlist.name}"
      lines << ""
      lines << "- song_count: #{playlist.song_count}"
      lines << "- created_at: #{playlist.created_at}"
      lines << "- tags: #{tags.join(' ')}"
      lines << ""
      lines << "| title | album | artist | path |"
      lines << "| --- | --- | --- | --- |"
      tracks.each do |track|
        lines << "| #{markdown_cell(track.title)} | #{markdown_cell(track.album)} | #{markdown_cell(track.artist)} | #{markdown_cell(track.path)} |"
      end
      lines << ""
      lines.join("\n")
    end

    def fetch_tracks(playlist_id)
      database.execute(<<~SQL, [playlist_id]).map do |title, album, artist, path|
        SELECT m.title, m.album, m.artist, m.path
        FROM playlist_tracks pt
        JOIN media_file m ON m.id = pt.media_file_id
        WHERE pt.playlist_id = ?
        ORDER BY pt.id ASC
      SQL
        Track.new(title: title, album: album, artist: artist, path: path)
      end
    end

    def database
      @database ||= SQLite3::Database.new(@database_path)
    end

    def compile_patterns(patterns)
      patterns.map do |pattern|
        if regex_pattern?(pattern)
          { type: :regex, value: Regexp.new(pattern[1..-2]) }
        else
          { type: :substring, value: pattern.downcase }
        end
      rescue RegexpError => e
        raise Error, "Invalid regex pattern #{pattern.inspect}: #{e.message}"
      end
    end

    def regex_pattern?(pattern)
      pattern.length >= 2 && pattern.start_with?("/") && pattern.end_with?("/")
    end

    def safe_filename(name)
      sanitized = name.gsub(/[\/\\:\*\?\"<>\|\u0000-\u001f]/, "_").strip
      sanitized.empty? ? "playlist" : sanitized
    end

    def normalize_tag(tag)
      tag.to_s.strip.gsub(/\s+/, "_").delete_prefix("#").gsub(/[^\p{Alnum}_\-\/\p{Han}\p{Hiragana}\p{Katakana}]/, "_")
    end

    def normalize_tag_path(name)
      normalize_tag(name).gsub("/", "_")
    end

    def markdown_cell(value)
      value.to_s.gsub("\\", "\\\\").gsub("|", "\\|").gsub("\n", "<br>")
    end
  end
end

NavidromeBackup::CLI.new(ARGV).run

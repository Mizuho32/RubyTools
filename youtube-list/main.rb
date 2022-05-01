#!/usr/bin/env ruby
# coding: utf-8

require 'yaml'
require 'pathname'

require 'google/apis/youtube_v3'

require_relative "lib"

# ARGV: list.yaml  apikey.txt  listid.txt

listyaml = Pathname(ARGV.first)
list = YAML.load_file(ARGV.first) rescue []

tube = Google::Apis::YoutubeV3::YouTubeService.new
tube.key = ARGV[1]

last_name = list.empty? ? /^$/ :  Regexp.new(Regexp.escape(list[-1][:name]))
videos = get_until(tube, ARGV[2].to_s, last_name, max_results: 10)
  .map{|itm|
    {name: itm[:title], url: "https://www.youtube.com/watch?v=#{ itm[:video_id] }" }
  }.reverse


puts "Delta: \n#{videos.map{|itm| itm[:name]}.join("\n")}\n------"

yml = (list + videos).to_yaml
#puts yml
File.write(listyaml, yml)

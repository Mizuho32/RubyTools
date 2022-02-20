#!/usr/bin/env ruby
# coding: utf-8

require 'yaml'

require 'google/apis/youtube_v3'

require_relative "lib"

# ARGV: list.yaml  apikey.txt  listid.txt

list = YAML.load_file(ARGV.first)

tube = Google::Apis::YoutubeV3::YouTubeService.new
tube.key = ARGV[1]

videos = get_until(tube, ARGV[2].to_s, Regexp.new(Regexp.escape(list[-1][:name])), max_results: 10)
  .map{|itm|
    {name: itm[:title], url: "https://www.youtube.com/watch?v=#{ itm[:video_id] }" }
  }.reverse


puts "Delta: \n#{videos.map{|itm| itm[:name]}.join("\n")}\n------"

yml = (list + videos).to_yaml
#puts yml
File.write(ARGV.first, yml)

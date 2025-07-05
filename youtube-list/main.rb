#!/usr/bin/env ruby
# coding: utf-8

require 'yaml'
require 'pathname'

require 'google/apis/youtube_v3'

require_relative "lib"

begin

$strio = if defined? RemoteSTDIO then StringIO.new else $stdout end

# ARGV: list.yaml  apikey.txt  listid.txt [last_idx]

listyaml = Pathname(ARGV.first)
list = YAML.load_file(ARGV.first) rescue []

tube = Google::Apis::YoutubeV3::YouTubeService.new
tube.key = ARGV[1]
last_idx = (ARGV[3] || -1).to_i

$strio.puts("## Start #{listyaml} backup #{Time.now.iso8601}")


last_name = list.empty? ? /^$/ :  Regexp.new(Regexp.escape(list[last_idx][:name]))
videos = get_until(tube, ARGV[2].to_s, last_name, max_results: 10)
  .map{|itm|
    {name: itm[:title], url: "https://www.youtube.com/watch?v=#{ itm[:video_id] }" }
  }.reverse

if videos.empty? then
  $strio.puts "No update for #{listyaml}. End."
  puts $strio.string if $strio.is_a?(StringIO)
  exit
end

puts $strio.string if $strio.is_a?(StringIO)
print """
Delta:
#{videos.map{|itm| itm[:name]}.join("\n")}
------
OK?>>"""
ret = safe_gets()

if !ret.downcase.include?(?y) then
  puts 'Delta not OK. End'
  exit
end

yml = (list + videos).to_yaml
#puts yml
File.write(listyaml, yml)

## git commit
Dir::chdir(listyaml.parent)

listyamlname = listyaml.basename.to_s
videonames = videos.map{|itm| itm[:name]}
diff = `git diff #{listyamlname}`
cmd = "git add #{listyamlname} && git commit -m '#{listyamlname} #{videonames.first} - #{videonames[-1]}'"
print """
**Diff is:**
```
#{diff}
```

**will run:*
```bash
$ #{cmd}
```
Diff OK? >>"""

if safe_gets().downcase.include?(?y) then
  ret =  system(cmd)
  puts "git commit with return #{ret}"
else
  puts 'No git commit'
  exit
end

rescue StandardError => ex
  puts("Error: #{__FILE__} #{ARGV.join(' ')}}", ex.message, ex.backtrace.join("\n"))
  exit 1
end

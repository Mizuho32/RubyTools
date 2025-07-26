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
list = list.reverse if ENV['REVERSE']

tube = Google::Apis::YoutubeV3::YouTubeService.new
tube.key = ARGV[1]
listid_yaml = YAML.load_file(ARGV[2])
listid = listid_yaml[:id]
last_idx = ( (!ARGV[3].to_s.empty? && ARGV[3]) || -1).to_i
obs_page_name = listid_yaml[:name]
OBS_DIR = Pathname(ENV['OBS_DIR'].to_s)

$strio.puts("## Start #{listyaml} backup #{Time.now.iso8601}")

# fetch
last_name = list.empty? ? /^$/ :  Regexp.new(Regexp.escape(list[last_idx][:name]))
videos = get_until(tube, listid, last_name, max_results: 10)
  .map{|itm|
    {name: itm[:title], url: "https://www.youtube.com/watch?v=#{ itm[:video_id] }" }
  }.reverse

music_list = list + videos

# Markdown out
#puts(obs_page_name, OBS_DIR)
if !obs_page_name.to_s.empty? && OBS_DIR.exist? then
  markdown_path = OBS_DIR / "#{obs_page_name}.md"
  markdown = """## [#{obs_page_name}](https://youtube.com/playlist?list=#{listid})
#music

#{music_list
    .select{|item| /^(?:priv|dele)/i !~ item[:name] }
    .map{|item| "- [#{item[:name].gsub(/(\[|\])/, '\\\\' + '\1')}](#{item[:url]})"}
    .join("\n")
}
"""
  #puts(markdown_path, markdown)
  File.write(markdown_path, markdown) if !markdown_path.exist? || !videos.size.zero?
end

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

# Output yaml
yml = music_list.to_yaml
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

**will run:**
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
  puts("Error: #{__FILE__} #{ARGV.join(' ')}", ex.message, ex.backtrace.join("\n"))
  exit 1
end

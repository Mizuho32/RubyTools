#!/usr/bin/env ruby
# coding: utf-8

require 'pathname'
require 'yaml'

# ARGV: list.yaml [last_idx]

yaml_path = Pathname(ARGV.first)
target_dir = yaml_path.dirname

downloadeds = target_dir
  .glob("*")
  .map{|path| path.basename.to_s }
  .select{|name| name =~ /^\d+/}
  .sort{|lname, rname| 
    /^(\d+)/.match(lname)[1].to_i(10) <=> /^(\d+)/.match(rname)[1].to_i(10)
  }.map{|name|
    [/^(\d+)/.match(name)[1].to_i(10), /([^\s]+)\.[^\.]+$/.match(name)[1].to_sym, name] } # video id

#puts downloadeds

downloadeds_map = Hash[downloadeds.map{|idx, id, name| [id, [idx, name]]}]


yaml = YAML.load_file(yaml_path)
yaml_map = Hash[ yaml.map{|item| [item[:url][/=([^=]+)/, 1].to_sym, item]} ]

# check consistency
## check downloadeds in yaml
d_in_y = downloadeds.group_by{|idx, id, name|
  #puts "check #{id} #{id.class} (#{name} in yaml"
  has_id = yaml_map.has_key? id
  has_id
}

if d_in_y[false]&.empty? == true then
  puts 'Add deleteds to yaml...'
  d_in_y[false].each{|idx,id,name|
    name = name.sub(/^\d+ - /, '').sub(/ #{id}/, '').strip
    url = "https://www.youtube.com/watch?v=#{id}"
    puts "  add #{idx} #{name}"
    yaml.insert(idx - 1, {name: name, url: url})
  }
  File.write(yaml_path, yaml.to_yaml)
end

if not downloadeds.map{|i, id, name| yaml_map.has_key? id }.all? then
  $stderr.puts "Inconsistent! Exit"
  exit 1
else
  puts "# Consistency OK"
end


# Gen download script
y_in_d = yaml_map.keys.each_with_index.group_by{|id, idx|
  downloadeds_map.has_key? id
}

newly_downloads = (y_in_d[false]||[])
  .select{|id, idx| yaml_map[id][:name] !~ /^(delete|private)/i }
  .sort{|(_, idxl),(_,idxr)| idxl <=> idxr }

last_idx = (ARGV[1]|| -1).to_i
last_index = downloadeds[last_idx].first
puts "# last_index #{last_index} #{last_idx}"

cmds = newly_downloads.each_with_index.map{|(id, _), i|
  idx = last_index + i
  out_path = (target_dir / "#{idx.succ} - %(title)s %(id)s.%(ext)s").to_s
  url = yaml_map[id][:url]
  cmd = %Q|yt-dlp --match-filter "duration < 1200" -o "#{out_path}" "#{url}"|
}.join("\n")

puts cmds

#puts "last number is #{last}"
#puts <<-"EOF"
#yt-dlp --match-filter "duration < 1200" --playlist-start #{last+1} -o "%(playlist_index)s - %(title)s %(id)s.%(ext)s" "https://www.youtube.com/playlist?list=PLavJaWSqKmCx3p3GTL2rTrkrls6aptcX1"
#EOF

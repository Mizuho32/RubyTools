#!/usr/bin/env ruby
# coding: utf-8

require 'pathname'
require 'yaml'
require 'open3'
require 'fileutils'
require_relative 'lib'

begin

# ARGV: list.yaml [last_idx]


yaml_path = Pathname(ARGV.first)
target_dir = yaml_path.dirname
puts "## Download #{target_dir}"

downloadeds = target_dir
  .glob("*")
  .map{|path| path.basename.to_s }
  .select{|name| name =~ /^\d+/}
  .sort{|lname, rname| 
    /^(\d+)/.match(lname)[1].to_i(10) <=> /^(\d+)/.match(rname)[1].to_i(10)
  }.map{|name|
    [/^(\d+)/.match(name)[1].to_i(10), /([^\s]+)\.[^\.]+$/.match(name)[1].to_sym, name] } # video id
# idx, id, filename

#puts downloadeds

downloadeds_map = Hash[downloadeds.map{|idx, id, name| [id, [idx, name]]}]


yaml = YAML.load_file(yaml_path)
yaml_map = Hash[ yaml.map{|item| [item[:url][/=([^=]+)/, 1].to_sym, item]} ] # id -> item

# check consistency
## check downloadeds in yaml
d_in_y = downloadeds.group_by{|idx, id, name|
  #puts "check #{id} #{id.class} (#{name} in yaml"
  has_id = yaml_map.has_key? id
  has_id
}

if d_in_y[false]&.empty? == true then
  deleteds = d_in_y[false].map{|idx,id,name|
    name = name.sub(/^\d+ - /, '').sub(/ #{id}/, '').strip
    url = "https://www.youtube.com/watch?v=#{id}"
    yaml.insert(idx - 1, {name: name, url: url})
    "  add #{idx} #{name}"
  }.join("\n")
  print """Add deleteds to yaml...
#{deleteds}
Update yaml?>>"""
  if not gets =~ /no?/i then
    File.write(yaml_path, yaml.to_yaml)
  end
end

if not downloadeds.map{|i, id, name| yaml_map.has_key? id }.all? then
  $stderr.puts "Inconsistent! Exit"
  exit 1
end

## idx consistency
idx_updates = yaml_map
  .each_with_index.map{|(id, item), idx_yml|
    idx_d, name_d = downloadeds_map[id]
    #puts("None for #{id}") if name_d.nil? || name_d.empty?
    [idx_yml+1, idx_d, name_d]
  }.select{|idx_yml, idx_d, name_d|
    !name_d.nil? && idx_yml != idx_d
  }

if !idx_updates.empty? then
  tmp = idx_updates.map{|idx_yml, idx_d, name_d|
    "#{idx_d}->#{idx_yml} #{name_d}"
  }.join("\n")
  print """### index updates
```
#{tmp}
```
Update indices? >>"""

  if safe_gets.downcase.include?(?y) then
    idx_updates.each{|idx_yml, idx_d, name_d|
      newname = name_d.sub(/^[^\s]+/, idx_yml.to_s)
      src = target_dir / name_d
      dst = target_dir / newname

      if dst.exist? then
        $stderr.puts("#{dst} exists! SKip.")
      else
        #puts("mv #{src} -> #{dst}")
        FileUtils.mv(src, dst)
      end
    }
  end
end

puts "Consistency OK"

# Gen download script
#Dir::chdir(target_dir)

y_in_d = yaml_map.keys.each_with_index.group_by{|id, idx|
  downloadeds_map.has_key? id
}

newly_downloads = (y_in_d[false]||[])
  .select{|id, idx| yaml_map[id][:name] !~ /^(delete|private)/i }
  .sort{|(_, idxl),(_,idxr)| idxl <=> idxr }

if newly_downloads.empty? then
  puts "No updates. End."
  exit
end

last_index = yaml_map.size + 1

result = newly_downloads.each_with_index.map{|(id, _), i|
  next if yaml_map[id][:skip]

  idx = last_index + i
  url = yaml_map[id][:url]
  durations = yaml_map[id][:durations] || ['']
  out = durations.map {|duration|
    durat_txt = if duration.empty? then duration else "_#{duration}" end
    durat_opt = if duration.empty? then ' --match-filter "duration < 1200"' else %Q|--download-sections "*#{duration}"| end
    
    out_path = (target_dir / "#{idx.succ} - %(title)s#{durat_txt} %(id)s.%(ext)s").to_s
    cmd = %Q|yt-dlp -o "#{out_path}" #{durat_opt} "#{url}"|

    name = yaml_map[id][:name]
    out, err, status = Open3.capture3(cmd)
    if status.exitstatus.zero? then
      name << " OK"
    else
      name << " Err\n#{err}"
    end
    name << "\n#{cmd}"
    name
  }.join("\n")
  puts out
}.join("\n")

#puts result

#puts "last number is #{last}"
#puts <<-"EOF"
#yt-dlp --match-filter "duration < 1200" --playlist-start #{last+1} -o "%(playlist_index)s - %(title)s %(id)s.%(ext)s" "https://www.youtube.com/playlist?list=PLavJaWSqKmCx3p3GTL2rTrkrls6aptcX1"
#EOF

rescue StandardError => ex
  puts("Error: #{__FILE__} #{ARGV.join(' ')}}", ex.message, ex.backtrace.join("\n"))
  exit 1
end

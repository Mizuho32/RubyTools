#!/usr/bin/env ruby
# coding: utf-8

text = STDIN.read || File.read(ARGV.first)

def format(time_str, digit=3)
  time = time_str.split(?:).reverse.each_with_index.map{|time, i| time.to_i*60**i}.sum
  #puts "time #{time_str} is #{time}"
  Time.at(time).utc.strftime("%H:%M:%S")
end

puts text.split("\n").map{|line|
  if m = line.match(/(\d+(:\d+)+)([^\d]+.+)/) then
    format(m[1]) + m[3]
  else
    line
  end
}.join("\n")

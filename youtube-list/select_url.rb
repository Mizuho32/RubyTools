#!/usr/bin/env ruby
# coding: utf-8

require 'yaml'

require "oga"

require_relative 'lib'

doc  = Oga.parse_html(File.read(ARGV[1]))

list = 
if ARGV.first == ?1
  html2musiclist(doc)
elsif ARGV.first == ?2
  html2musiclist2(doc)
end

puts list.to_yaml

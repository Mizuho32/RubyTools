#!/usr/bin/env ruby
# coding: utf-8

require 'yaml'
require 'pathname'
require 'open3'
require 'time'
require 'stringio'

require_relative 'lib'
require_relative '../youtube-list/lib'

# ARGV: git_dir
#
begin

$strio = if defined? RemoteSTDIO then StringIO.new else $stdout end
git_dir = Pathname(ARGV.first)

unless git_dir.exist? then
  $stderr.puts("No #{git_dir}!")
  exit 1
end

# git status
Dir::chdir(git_dir)
stdout, stderr, status = Open3.capture3('git status')
unless status.exitstatus.zero? then
  $stderr.puts(stdout, stderr)
  exit 2
end

# main
git_out = stdout
exit if git_out.include?('nothing to commit, working tree clean')

git_out, states = beautify_git(git_out)
num_canbe_added = states.values.map{ _1[:count] }.sum
print("""= Git backup #{git_dir}

_At #{Time.now.iso8601}_
*#{num_canbe_added}* items can be added/modified/deleted

*Status is:*

#{git_out}

Ok to add & commit? >> """)

# puts $strio.string if $strio.is_a?(StringIO)
if safe_gets().downcase.include?(?y) then
  cmd = "git add . && git commit -m 'AutoBackup: #{num_canbe_added} items added/modified/deleted at #{Time.now.iso8601}.'"
  ret = puts cmd
  ret =  system(cmd)
  puts "git commit with return #{ret}"
else
  puts 'Canceled git commit'
end

rescue StandardError => ex
  puts("Error: #{__FILE__} #{ARGV.join(' ')}", ex.message, ex.backtrace.join("\n"))
  exit 1
end

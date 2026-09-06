#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'


# 標準入力から受け取る
input_data = $stdin.read

# 標準出力に出力
puts input_data

host_port = ARGV.first
exit(0) if host_port.nil?

port = 8001

# For $SSH_CLIENT like '192.168.0.1 12345 22'
host_port = "#{host_port[/(?<host>[^\s]+)\s/, :host]}:#{port}" if !host_port.include?(?:)

# REST APIのエンドポイントURLを指定
api_url = "http://#{host_port}"

# REST APIにPOSTリクエストを送信
uri = URI.parse(api_url)
http = Net::HTTP.new(uri.host, uri.port)
#http.use_ssl = (uri.scheme == "https")

request = Net::HTTP::Post.new(uri.request_uri, {'Content-Type' => 'application/json'})
request.body = { data: input_data.strip }.to_json

response = http.request(request)

# レスポンスを標準出力に出力
#$stderr.puts "Response from API: #{response.body}"

#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'


# 標準入力から受け取る
input_data = $stdin.read

# 標準出力に出力
puts input_data

exit(0) if ARGV[0].nil?

# REST APIのエンドポイントURLを指定
api_url = "http://#{ARGV[0]}"

# REST APIにPOSTリクエストを送信
uri = URI.parse(api_url)
http = Net::HTTP.new(uri.host, uri.port)
#http.use_ssl = (uri.scheme == "https")

request = Net::HTTP::Post.new(uri.request_uri, {'Content-Type' => 'application/json'})
request.body = { data: input_data.strip }.to_json

response = http.request(request)

# レスポンスを標準出力に出力
#$stderr.puts "Response from API: #{response.body}"

#
#/usr/bin/env ruby

require 'json'
require 'sinatra'
require 'pathname'

ENV['DISPLAY'] = ':0' unless ENV['DISPLAY']
copy_cmd = if system("which xsel") then
            "xsel -i --clipboard"
           elsif system("which wl-copy") then
             "wl-copy"
           else
             exit 2
           end

post '/' do
  # リクエストボディを取得して標準出力に出力
  data = JSON.parse(request.body.read, symbolize_names: true)
  p data
	input_data = data[:data]

  if input_data then
    # copy to clipboard
    IO.popen(copy_cmd, "r+") do |io|
      io.print input_data
      io.close_write

      puts "to clipbard: #{io.read}"
    end

    # レスポンスを返す
    "OK"
  else
    "No data"
  end
end

get '/test' do
  p params
  p ENV['DISPLAY']
end


# サーバーを起動するための設定
set :port, (ARGV[0] || 8001).to_i
set :bind, "0.0.0.0"

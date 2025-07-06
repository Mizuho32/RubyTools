#
#/usr/bin/env ruby

require 'json'
require 'sinatra'

post '/' do
  # リクエストボディを取得して標準出力に出力
  data = JSON.parse(request.body.read, symbolize_names: true)
  p data
	input_data = data[:data]

  if input_data then
    # copy to clipboard
    command = "xsel -i --clipboard"

    IO.popen(command, "r+") do |io|
      io.print input_data
      io.close_write

      puts "xsel: #{io.read}"
    end

    # レスポンスを返す
    "OK"
  else
    "No data"
  end
end

get '/test' do
  p params
end

# サーバーを起動するための設定
set :port, (ARGV[0] || 8001).to_i
set :bind, "0.0.0.0"

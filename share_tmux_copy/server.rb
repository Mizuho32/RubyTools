require 'json'
require 'sinatra'

post '/' do
  # リクエストボディを取得して標準出力に出力
  request.body.rewind
  data = JSON.parse(request.body.read, symbolize_names: true)
  #data = request.body.read
  p data
  
  # レスポンスを返す
  #"Received data: #{data}"
  "OK"
end

# サーバーを起動するための設定
set :port, ARGV[0].to_i

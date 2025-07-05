def html2musiclist(doc)
  doc
    .xpath(%Q{//tbody[@id="pl-load-more-destination"]/tr/td/a[@dir="ltr"]})
    .map{|e| { name: e.children.first.text.strip, url: e.attribute(:href).value } }
end

def html2musiclist2(doc)
  names = doc
    .xpath('//h3/span[@class="style-scope ytd-playlist-video-renderer"]')
    .map{|e| e.attribute(:title)&.value }.compact
  urls = doc
    .xpath('//div[@id="contents"]/ytd-playlist-video-renderer/div[@id="content"]/a[@class="yt-simple-endpoint style-scope ytd-playlist-video-renderer"]')
    .map{|e| e.attribute(:href).value }
  
  names.zip(urls).map{|e| {name: e.first, url: e.last}}
end


def get_until(tube, id, title_reg, video_id_reg=/^$/, max_results: 5)
  page_token = nil
  videos = []

  loop do
    res = tube.list_playlist_items('snippet,contentDetails', playlist_id: id.to_s, max_results: max_results, page_token: page_token)
    page_token = res.next_page_token

    filtered = res.items.map{|itm|
      title, video_id = itm.snippet.title, itm.content_details.video_id

      [title, video_id]
    }.take_while{|(title, video_id)|
      not (title_reg =~ title or video_id_reg =~ video_id)
    }.each{|(title, video_id)|
      #puts title
      videos << {title: title, video_id: video_id}
    }

    is_hit = filtered.size < max_results
    #p filtered, page_token

    break if is_hit or page_token.to_s.empty?
  end

  return videos
end

begin
  host = ENV['HOST'].to_s
  client_id = ENV['CID'].to_s
  if !host.empty? && !client_id.empty? then
    require 'remotestdio'
    RemoteSTDIO.init(host, client_id)
  else
    NO_REMOTESTDIO = true
    puts "WARN puts without remotestdio"
  end
rescue LoadError => ex
  puts ex.message
  puts "WARN puts without remotestdio"
  NO_REMOTESTDIO = true
end

def safe_gets()
  if defined? NO_REMOTESTDIO then
    return STDIN.gets
  else
    return gets
  end
end


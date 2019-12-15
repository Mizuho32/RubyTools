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

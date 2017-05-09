
def js(file, port)
<<-"EOF"
<script>
(()=>{
  var ws = new WebSocket("ws://localhost:#{port}");

  ws.onopen = ()=>{
    ws.send("#{file}");
  };

  ws.onmessage =  (e)=>{
    location.reload();
  };

})()
</script>
EOF
end

def insert(src, script)
  doc = Oga.parse_html(src)

  # auto reload script
  spt = Oga.parse_html(script)
  ( nodeset = doc.at_xpath("html/head").children ).insert( nodeset.size, spt.at_xpath("script") )

  # mathJax numbering
  if mathconf = doc.at_xpath('//script[@type="text/x-mathjax-config"]') then
    mathconf.children.first.text[/autoNumber:\s*"([^"]+)"/,1] = "AMS"
  end

  doc
end

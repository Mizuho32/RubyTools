require 'pathname'

srv = <<-"EOL"
[Unit]
Description=local server: tmux share, portal, etc.

[Service]
Type=simple
ExecStart=/bin/bash -c 'export MISE_DATA_DIR=$HOME/media/data/mise && eval "$(mise activate bash)" && which ruby && ruby -v && exec bash #{ENV['PWD']}/launch.sh'

[Install]
WantedBy=default.target
EOL

puts srv

path = "#{ENV['HOME']}/.config/systemd/user/#{Pathname(__FILE__).basename('.rb')}"
puts "Wrote to #{path}"
File.write(path, srv)

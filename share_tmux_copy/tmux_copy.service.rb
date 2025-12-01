srv = <<-"EOL"
[Unit]
Description=tmux clipboard sharer

[Service]
Type=simple
ExecStart=bash #{ENV['PWD']}/share_tmux_copy/launch.sh

[Install]
WantedBy=default.target
EOL

puts srv

path = "#{ENV['HOME']}/.config/systemd/user/tmux_copy.service"
puts "Wrote to #{path}"
File.write(path, srv)

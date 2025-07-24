
$stderr.puts <<-"EOF"
Usage:
$ #{Main::FILE} command [opts..]

commands:
  server    ws_port http_port base_dir  : launch server
    default 5000    4000      .

  init      asciidoc_file_name          : init current dir
    default hello

  install   target_dir                  : install
    default ~/bin
EOF

exit 1

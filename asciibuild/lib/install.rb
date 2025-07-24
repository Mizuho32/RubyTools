module Install
  TargetDir = Pathname(ARGV[1] || "~/bin").expand_path.to_s

  Dir::mkdir("#{TargetDir}/") unless File.exists?("#{TargetDir}/")
  File.open("#{TargetDir}/#{Main::FILE}", "w"){|f|
    f.write <<-"EOF"
#!/bin/sh

BUNDLE_GEMFILE=#{Main::FILE_DIR}/Gemfile #{Main::FILE_DIR}/#{Main::FILE} "$@"
EOF
  FileUtils.chmod("u+x", "#{TargetDir}/#{Main::FILE}")
  }
end

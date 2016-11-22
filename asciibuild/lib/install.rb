module Install
  TargetDir = Pathname(ARGV[1] || "~/bin").expand_path.to_s

  Dir::mkdir("#{TargetDir}/") unless File.exists?("#{TargetDir}/")
  FileUtils.ln_s("#{Main::FILE_DIR}/#{Main::FILE}", "#{TargetDir}/")
end

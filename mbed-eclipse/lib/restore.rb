
module Restore

  WORKSPACE_DIR = Pathname(ARGV[1] || "~/workspace").expand_path
  DIR = Pathname(?.).expand_path.to_s

  PROJ = Oga.parse_xml( File.open("#{DIR}/.project", "r").read )
  PROJ_NAME = PROJ.at_xpath("projectDescription/name").children.first.text


  unless File.exists?("backup") then
    $stderr.puts "backup/ not found"
    exit 1
  end

  Dir::chdir(DIR + "/backup")
  FileUtils.cp_r(%w[.project .cproject .settings], "../")
  FileUtils.cp(Dir.glob("#{PROJ_NAME}*"), "#{WORKSPACE_DIR}/.metadata/.plugins/org.eclipse.cdt.core/")


end

module Init
  StylesDir = "css"
  ImagesDir = "img"
  HighlightjsDir = "highlight"

  DIR = Pathname(?.).expand_path.to_s
  Dir::chdir(DIR)

  FileUtils.cp_r("#{Main::FILE_DIR}/assets/#{StylesDir}",       "./")
  FileUtils.cp_r("#{Main::FILE_DIR}/assets/#{HighlightjsDir}",  "./")
  FileUtils.cp_r("#{Main::FILE_DIR}/assets/#{ImagesDir}",  "./")

  head = <<-"EOF"
:source-highlighter: highlightjs
:highlightjsdir: #{HighlightjsDir}
:highlightjs-theme: ir-black
:imagesdir: #{ImagesDir}
:stylesdir: #{StylesDir}
:icons: font
:stem: latexmath
:linkcss:
:sectnums:
EOF

  File.open("#{DIR}/#{ARGV[1] || "hello"}.adoc", "w+").write(head + File.open("#{Main::FILE_DIR}/assets/templ.adoc", "r").read)
end

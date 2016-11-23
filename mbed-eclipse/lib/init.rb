require 'yaml'
require 'lib/filter'


module Init

  OS = ARGV[1] || 5
  WORKSPACE_DIR = Pathname(ARGV[2] || "~/workspace").expand_path

  def backup
    return if File.exists?("backup")

    Dir.mkdir("backup") 
    FileUtils.cp_r(%w[.project .cproject .settings]+Dir.glob("#{WORKSPACE_DIR}/.metadata/.plugins/org.eclipse.cdt.core/#{PROJ_NAME}*"), "backup")

  end
  
  def insert_symbols_and_includes

    h_files = Dir.glob("symbols/*.h")
    prefix = "org.eclipse.cdt.core."
    entries = h_files.map{|name|
      case name
        when /as(?:se)?m(?:bly)?/i              then # ASM
          [:"#{prefix}assembly", name]
        when /(?:(?:c|g)([^c])\1)|(?:plus|\+)/i    then # C++
          [:"#{prefix}g++", name]
        when /(?:(?:[^a-z]|\A|^)c(?:[^a-z]|\b|$))|gcc/i then # C
          [:"#{prefix}gcc", name]
        else
          $stderr.puts "unknown language type"
          [nil, name]
      end
    }.inject({}){|o,(type,name)| o[type] = (o[type]||[]) << name; o}
    .map{|type, names|
      names.map do |name|
        <<-"EOF"
  <language id="#{type}">
    <resource project-relative-path="">
      <entry kind="macroFile" name="/${ProjName}/#{name}">
        <flag value="LOCAL|VALUE_WORKSPACE_PATH" />
      </entry>
      <entry kind="includeFile" name="/${ProjName}/mbed_config.h">
        <flag value="LOCAL|VALUE_WORKSPACE_PATH"/>
      </entry>
#{type.to_s.include?("g++") ? Init.include_entries : ""}
    </resource>
  </language>
EOF
      end
    }.join
  
    provider = <<-"EOF"
<provider id="org.eclipse.cdt.ui.UserLanguageSettingsProvider">
#{entries}</provider>
EOF

      lang_xml = Oga.parse_xml(File.read("#{WORKSPACE_DIR}/.metadata/.plugins/org.eclipse.cdt.core/#{PROJ_NAME}.language.settings.xml"))

      File.open("#{WORKSPACE_DIR}/.metadata/.plugins/org.eclipse.cdt.core/#{PROJ_NAME}.language.settings.xml", "w"){|f|
        lang_xml.at_xpath("project/configuration[@name='Default']/extension").children.insert(0, Oga.parse_xml(provider).root_node.children.first)
        #puts lang_xml.to_xml
        f.write(lang_xml.to_xml)
      }
  end

  def modifi_lang_settings_xml
    lang_settings_xml = Oga.parse_xml( File.read("#{DIR}/.settings/language.settings.xml") )
    provider = lang_settings_xml.at_xpath("project/configuration[@name='Default']/extension/provider[@id='org.eclipse.cdt.ui.UserLanguageSettingsProvider']")
    provider.attributes.delete_if{|at| at.name == "copy-of"}
    elem = provider
    ns_name = provider.namespace_name
    provider.attributes  \
    << Oga::XML::Attribute.new(name:"name", value:"CDT User Settring Entries", element:elem, namespace_name:ns_name)  \
    << Oga::XML::Attribute.new(name:"prefer-non-shared", value:"true", element:elem, namespace_name:ns_name) \
    << Oga::XML::Attribute.new(name:"class", value:"org.eclipse.cdt.core.language.settings.providers.LanguageSettingsGenericProvider", element:elem, namespace_name:ns_name)

    #pp provider
    #puts lang_settings_xml.to_xml
    File.open("#{DIR}/.settings/language.settings.xml", "w"){|f|
      f.write(lang_settings_xml.to_xml)
    }
  end

  def include_entries
    Dir.glob("#{DIR}/symbols/*").select{|n| n !~ /\.h/ and n =~ /include/i}.inject([]){|o, file|
      o + YAML.load_file(file)
    }.map{|n|
      <<-"EOF"
      <entry kind="includePath" name="/${ProjName}/#{n}">
        <flag value="LOCAL|VALUE_WORKSPACE_PATH" />
      </entry>
EOF
    }.join
=begin
    cproject = Oga.parse_xml(File.read("#{DIR}/.cproject"))
    nodes = [:assembler, :'c.compiler', :'cpp.compiler'].inject({}){|o,tool|
      tmp = o[tool] = cproject.at_xpath("cproject/storagemodule[@moduleId='org.eclipse.cdt.core.settings']/cconfiguration/storagemodule[@moduleId='cdtBuildSystem']/configuration/folderinfo/toolchain/tool[@superClass='ilg.gnuarmeclipse.managedbuild.cross.tool.#{tool}']") 
      puts tool
      includes.children.each{|e| (pp tmp.at_xpath("option")).children << e}
      #puts tmp.to_xml
      o
    }
<listOptionValue builtIn="false" value="&quot;${workspace_loc:/#{PROJ_NAME}/#{n}}&quot;" />
=end
  end
 
end

Init.filter_symbols
Init.backup
Init.insert_symbols_and_includes
Init.modifi_lang_settings_xml

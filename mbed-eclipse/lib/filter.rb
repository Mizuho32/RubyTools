require 'yaml'

module Init
  extend self

  DIR = Pathname(?.).expand_path.to_s
  Dir::chdir(DIR)

  PROJ = Oga.parse_xml( File.open("#{DIR}/.project", "r").read )
  PROJ_NAME = PROJ.at_xpath("projectDescription/name").children.first.text

  # filter symbol, includes
  def filter_symbols
    return  if File.exists?("symbols")

    system "mbed export -i gcc_arm" unless File.exists?("Makefile")
    filter = YAML.load_file("config.yaml") rescue ->(){ $stderr.puts("config.yaml missing");  exit(1); }.()

    
    flags = `make -pn | ruby -ne 'puts $_ if $_ =~ /^(#{(filter[:symbols]+filter[:includes]).join ?|})/'`.split("\n")

    flags_map = {}
    flags.map{|el|
      el =~ /\A(\w+)\s+\+?=\s+(.+)\b/
      key = $1
      val = $2.split(/\s+/)
      val.each{|el2|
        if el2.include?("-D")
          flags_map[k = "#{key}_D"] = (flags_map[k] || []) << (el2.sub("-D", ""))
        else
          flags_map[key] = (flags_map[key]||[]) << el2
        end
      }
    }

    Dir::mkdir("symbols")
    Dir::chdir("symbols")

    flags_map.each{|type, symbols|
      if type =~ /_D$/ then
        File.open("#{type}.h", "w+") do |f| 
          f.write(
            symbols.map{|el| 
              if el =~ /(.+)=(.+)/ then
                "#define #{$1} #{$2}"
              else
                "#define #{el}"
              end
            }.join("\n")
          )
        end
      elsif filter[:symbols].include? type then
        File.open("#{type}", "w+") do |f| 
          f.write(symbols.to_yaml)
        end
      elsif filter[:includes].include? type then
        File.open("#{type}", "w+"){ |f|
          f.write(symbols.map{|n| 
            if n =~ /^.+(mbed-os.+)$/ then
              $1
            else
              nil
            end
          }.compact.to_yaml)
        }
      end
    }

    Dir::chdir("../")
  end
end

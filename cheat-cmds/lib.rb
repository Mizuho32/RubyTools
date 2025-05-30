# typed: true
require 'sorbet-runtime'

module LIB
  extend self
  extend T::Sig

  sig { params(words: T::Array[String]).returns([T.nilable(Symbol), String]) }
  def get_search_words(words)
    if words.size == 1 then
      return words.first&.to_sym, ''
    else
      return words.first&.to_sym, words[1..]&.join(' ').to_s
    end
  end

  sig { params(cmdline: String).returns(Symbol) }
  def get_command_name(cmdline)
    cmdline[/[a-zA-Z]+/].to_s.to_sym
  end

  sig {params(n: Commonmarker::Node).returns(Commonmarker::Node)}
  def clone_node(n)
    Commonmarker.parse(n.to_commonmark)
  end

  sig {params(head_code: T::Hash[Symbol, T::Array[Commonmarker::Node]], lang_type: Symbol, query: String).returns(T.nilable(T::Array[Commonmarker::Node]))}
  def get_code_block(head_code, lang_type, query)

    code_block = head_code[lang_type]
    unless code_block then
      lang_type_guess = head_code.keys.select{|cand| cand.to_s.include?(lang_type.to_s)}.first
      if lang_type_guess.nil? then
        $stderr.puts("Unknown command #{lang_type}")
        Kernel.exit 5
      end

      code_block = head_code[lang_type_guess]
      if !query.empty? && code_block&.select{ _1.type == :code_block }&.all?{|node| !node.string_content&.include?(query) } then
        $stderr.puts("No words '#{query}' in '#{lang_type} (guessed: #{lang_type_guess})' section")
        Kernel.exit 6
      end
    end

    return code_block
  end

  sig {params(nodes: T::Enumerator[Commonmarker::Node]).returns(T::Hash[Symbol, T::Array[Commonmarker::Node]])}
  def head_nodes_pair(nodes)
    initial = T.let([{}, nil], [T::Hash[Symbol, Commonmarker::Node], T.nilable(Symbol)])
    tmp, _ = nodes.inject(initial) {|(hash, cur_head), node|
      hash = T.let(hash, T::Hash[Symbol, T::Array[Commonmarker::Node]])
      if node.type == :heading then
        cur_head = node.first_child&.string_content&.to_sym
        hash[cur_head] = [node] 
      else
        next [hash, cur_head] if cur_head.nil?
        hash[cur_head]&.append(node)
      end
      [hash, cur_head]
    }
    return tmp
  end
# head_code = Hash[T.let(doc.walk, T::Enumerator[Commonmarker::Node]).select { |node|
#   # node.type == :code_block || node.type == :heading
#   true
# }.each_slice(3).map{|heading_node, tag_node, codeblock_node|
#   tmp = T.let(heading_node&.first_child&.string_content&.to_sym, T.nilable(Symbol))
#   [tmp, [heading_node,  codeblock_node]]
# }.to_a]

  sig { params(text: String, command: String).returns(String) }
  def show_md(text, command = 'bat --language=markdown')
    IO.popen(command, 'w') do |io|
      io.write(text)
    end
    text
  end

  sig { params(text: String).returns(String)}
  def to_obs_md(text)
    text
      .gsub("\\#", ?#)
      .gsub(/```(?: )+([^\s]+)/, '```\1')
  end

  sig { params(text: String, new_line: String).returns(String)}
  def remove_LF_around_tag(text, new_line: "\n")
    # m = text.scan(/#{new_line}{2,}(#[^\s#]([^\n]|([^\n]\n[^\n]))+)#{new_line}{2,}/)
    # p(m) if m
    text.gsub(/#{new_line}{2,}(#[^\s#]([^\n]|([^\n]\n[^\n]))+)#{new_line}{2,}/, "\n\\1\n")
  end

  sig { params(cmdline: String).void }
  def run_interactive_cmd(cmdline)
    tty = File.open('/dev/tty', 'r+')
    pid = spawn({'TERM' => 'xterm-256color'}, cmdline, in: tty, out: tty, err: tty)
    Process.wait(pid)
    tty.close
  end

  sig { params(text: String).returns(String) }
  def prompt(text)
    tty = File.open('/dev/tty', 'r')
    Kernel.print(text)
    user_input = tty.gets
    tty.close
    user_input || ''
  end

end

#IO.popen('less -R', 'w') do |io|
#  io.write(text)
#end
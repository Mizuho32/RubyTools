# typed: true

require 'open3'
require 'pathname'
require 'fileutils'

require 'commonmarker'
require 'sorbet-runtime'

require_relative 'lib'

extend T::Sig

search = STDIN.tty?
register = T.let(nil, T.nilable(String))

if search && ARGV.empty? then
  $stderr.puts("Specify commands")
  exit 1
end

if !search && ((tmp = STDIN.gets).to_s.empty?) then
  $stderr.puts("Empty string given")
  exit 2
else
  register = tmp
end

# 任意のMarkdownテキスト
path = ENV['CHEAT_CMD_PATH']
if not path then
  $stderr.puts("Set $CHEAT_CMD_PATH!")
  exit 3
end

lang_type, query = if search then
  LIB.get_search_words(ARGV)
else
  [LIB.get_command_name(register.to_s), ""]
end

if lang_type.nil? then
  $stderr.puts("Unknown language type")
  exit 4
end

markdown_text = File.read(path)

# ASTを取得
doc = T.let(Commonmarker.parse(markdown_text), Commonmarker::Node)

# AST内をwalkして、rubyコードブロックを探す
# doc.walk do |node|
#   node = T.let(node, Commonmarker::Node)
#   if node.type == :code_block then #&& p node.fence_info == 'ruby'
#     # ここでコード内容を置き換える
#     #node.string_content += "puts 'Modified from script!'"
#   elsif node.type == :heading then
#     #puts node
#   end
# end

head_code = LIB.head_nodes_pair(T.let(doc.each, T::Enumerator[Commonmarker::Node]))

# p head_code.keys()
#p Hash[head_code.map{|k,v| [k, v.map{_1.type}]}.to_a]
# exit

# pp head_code
# puts head_code.size

# select code block
hit_nodes = LIB.get_code_block(head_code, lang_type, query)

if search then

  new_doc = T.let(Commonmarker::Node.new(:document), Commonmarker::Node)
  if hit_nodes&.each { |n| new_doc.append_child(n) } then
    LIB.show_md(LIB.to_obs_md(new_doc.to_commonmark))
  end

else
  # puts lang_type, hit_nodes.class
  code_block = hit_nodes&.select{ _1.type == :code_block }&.first
  code_block = T.must(code_block)
  code_block.string_content += "\n#{register}"

  new_doc = T.let(Commonmarker::Node.new(:document), Commonmarker::Node)
  if hit_nodes&.each { |n| new_doc.append_child(LIB.clone_node(n)) } then
    LIB.show_md(LIB.to_obs_md(new_doc.to_commonmark))
  end

  user_input = LIB.prompt('Edit? [y/n] >>')

  if user_input.to_s.downcase.include?(?y) then

    code_block_tmp = T.let(Commonmarker::Node.new(:document), Commonmarker::Node)
    code_block_tmp.append_child(LIB.clone_node(code_block))

    tmpfile = Pathname(%x|mktemp|)
    tmpfile_md = tmpfile.to_s.strip + ".md"
    puts tmpfile_md
    File.write(tmpfile, code_block_tmp.to_commonmark)
    FileUtils.mv(tmpfile, tmpfile_md)

    LIB.run_interactive_cmd("vim #{tmpfile_md}")

    tmpdoc = T.let(Commonmarker.parse(File.read(tmpfile_md)), Commonmarker::Node)
    new_code_block = tmpdoc.walk.select{ _1.type == :code_block }.first
    code_block.string_content = new_code_block&.string_content
  end

  out_md = T.let(doc.to_commonmark.strip, String)
    .then{ LIB.to_obs_md(_1) }
    .then{ LIB.remove_LF_around_tag(_1) }
    #.then{ LIB.show_md(_1) }

  # Show diff
  final_tmpfile_md = Pathname(%x|mktemp|).to_s.strip + ".md"
  File.write(final_tmpfile_md, out_md)
  LIB.run_interactive_cmd("diff -u '#{path}' '#{final_tmpfile_md}' | delta")
  if !LIB.prompt("Diff is OK? [y/n] >>").downcase.include?('y') then
    $stderr.puts("Abort to save.")
    exit 5
  end

  FileUtils.mv(final_tmpfile_md, path)
  puts "Written to #{path}"
end
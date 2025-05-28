require 'commonmarker'
require 'open3'

# 任意のMarkdownテキスト
path = ENV['CHEAT_CMD_PATH']
if not path then
  $stderr.puts("Set $CHEAT_CMD_PATH!")
  exit 2
end

markdown_text = File.read(path)
query = ARGV.first&.to_sym || :''

# ASTを取得
doc = Commonmarker.parse(markdown_text)

# AST内をwalkして、rubyコードブロックを探す
doc.walk do |node|
  if node.type == :code_block then #&& p node.fence_info == 'ruby'
    # ここでコード内容を置き換える
    #node.string_content += "puts 'Modified from script!'"
  elsif node.type == :heading then
    #puts node
  end
end

head_code = Hash[doc.walk.select { |node|
  node.type == :code_block || node.type == :heading
}.each_slice(2).map{|heading_node, codeblock_node|
  [heading_node.first_child&.string_content.to_sym, [heading_node,  codeblock_node]]
}.to_a]

# pp head_code
# puts head_code.size

new_doc = Commonmarker::Node.new(:document)
if head_code[query]&.each { |n| new_doc.append_child(n) } then
  puts new_doc.to_commonmark
end


if false then
  # 編集後のMarkdownを再出力
  modified_markdown = doc.to_commonmark.gsub("\\#", ?#)
  puts modified_markdown
end


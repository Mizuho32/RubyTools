

def beautify_git(text)
  current = nil
  states = {
    :'Changes to be committed:'       => { start_idx: -1, skip: 1, end: '', color: 'green', count: 0,
      match_pattern: /^(?<space>\s+)(?<text>(?:modifi|delete|rename|new)[^:]*:.+)$/ },
    :'Changes not staged for commit:' => { start_idx: -1, skip: 2, end: '', color: 'red'  , count: 0,
      match_pattern: /^(?<space>\s+)(?<text>(?:modifi|delete|rename|new)[^:]*:.+)$/ },
    :'Untracked files:'               => { start_idx: -1, skip: 1, end: '', color: 'red'  , count: 0,
      match_pattern: /^(?<space>\s+)(?<text>.+)$/ },
  }

  colored = text.split("\n").each_with_index.map{|line, idx|
    if current.nil? then
      if (state = states[line_sym = line.to_sym]) then
        current = [line_sym, state]
        state[:start_idx] = idx
      end
      next line
    else
      name, state = current
      next line if !(idx > state[:start_idx]+state[:skip])
      if line.empty? then
        current = nil
        next line 
      end
      
      state[:count] += 1
      m = line.match(state[:match_pattern])
      $stderr.puts(name, idx, line, state) if !m
      m[:space] + "[.#{state[:color]}]##{m[:text]}#"
    end
  }.join("\n")
  return colored, states
end

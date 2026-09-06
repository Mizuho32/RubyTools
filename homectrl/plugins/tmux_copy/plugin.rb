# frozen_string_literal: true

require "sinatra/base"
require "json"
require_relative "../../lib/homectrl/plugin"

module Homectrl
  module Plugins
    # Bridges tmux copy-mode selections into the local clipboard.
    # Ported as-is from the original share_tmux_copy/server.rb.
    class TmuxCopy < Sinatra::Base
      include Homectrl::Plugin
      plugin_name "tmux_copy"
      plugin_description "Bridges tmux copy-mode selections into the local clipboard"

      ENV["DISPLAY"] = ":0" unless ENV["DISPLAY"]

      COPY_CMD = if system("which xsel", out: File::NULL, err: File::NULL)
                   "xsel -i --clipboard"
                 elsif system("which wl-copy", out: File::NULL, err: File::NULL)
                   "wl-copy"
                 else
                   warn "[tmux_copy] no copy command found (xsel, wl-copy)"
                   nil
                 end

      post "/" do
        payload = JSON.parse(request.body.read, symbolize_names: true)
        input_data = payload[:data]
        next "No data" unless input_data
        next "No copy cmd" unless COPY_CMD

        IO.popen(COPY_CMD, "r+") do |io|
          io.print input_data
          io.close_write
          logger.info "to clipboard: #{io.read}"
        end
        "OK"
      end

      get "/test" do
        content_type :json
        { display: ENV["DISPLAY"], copy_cmd: COPY_CMD }.to_json
      end
    end
  end
end

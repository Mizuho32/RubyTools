# frozen_string_literal: true

require "sinatra/base"
require "yaml"
require "shellwords"
require_relative "../../lib/homectrl/plugin"

module Homectrl
  module Plugins
    # Lists services described in services.yaml, with links to open them
    # and buttons to start/stop them via `systemctl --user`.
    class Portal < Sinatra::Base
      include Homectrl::Plugin
      plugin_name "portal"
      plugin_description "Lists managed local services with open/start/stop controls"

      set :views, File.join(__dir__, "views")
      SERVICES_FILE = File.join(__dir__, "services.yaml")
      Service = Struct.new(:name, :description, :url, :unit, keyword_init: true)

      helpers do
        def services
          raw = YAML.safe_load(File.read(SERVICES_FILE), permitted_classes: [], aliases: false)
          raw.fetch("services").to_h do |entry|
            svc = Service.new(**entry.transform_keys(&:to_sym))
            [svc.name, svc]
          end
        end

        def find_service!(name)
          services.fetch(name) { halt 404, "unknown service: #{name}" }
        end

        def unit_status(unit)
          `systemctl --user is-active #{Shellwords.escape(unit)} 2>/dev/null`.strip
        end
      end

      get("/") { redirect "/portal" }

      get "/portal" do
        erb :index, locals: { services: services }
      end

      post "/portal/services/:name/start" do
        svc = find_service!(params[:name])
        system("systemctl", "--user", "start", svc.unit)
        redirect "/portal"
      end

      post "/portal/services/:name/stop" do
        svc = find_service!(params[:name])
        system("systemctl", "--user", "stop", svc.unit)
        redirect "/portal"
      end
    end
  end
end

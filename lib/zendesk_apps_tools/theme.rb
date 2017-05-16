# frozen_string_literal: true

require 'zendesk_apps_tools/theming/common'

module ZendeskAppsTools
  class Theme < Thor
    include Thor::Actions
    include ZendeskAppsTools::CommandHelpers
    include ZendeskAppsTools::Theming::Common
    desc 'preview', 'Preview a theme in development'
    shared_options(except: %i[clean unattended])
    sinatra_options
    method_option :role,
                  type: :string,
                  enum: %w[manager agent end_user anonymous],
                  default: 'manager',
                  desc: 'The role for the preview URL'
    def preview
      setup_path(options[:path])
      ensure_manifest!
      require 'faraday'
      initial_upload
      start_server
    end

    no_commands do
      def initial_upload
        payload = generate_payload.merge(role: options[:role])
        connection = get_connection(nil)
        connection.put do |req|
          req.url '/hc/api/internal/theming/local_preview'
          req.body = JSON.dump(payload)
          req.headers['Content-Type'] = 'application/json'
        end
      rescue Faraday::Error::ClientError => e
        say_error_and_exit e.message
      end

      def generate_payload
        payload = {}
        templates = Dir.glob(theme_package_path('templates', '*.hbs'))
        templates_payload = {}
        templates.each do |template|
          templates_payload[File.basename(template, '.hbs')] = File.read(template)
        end
        assets = Dir.glob(theme_package_path('assets', '*'))
        asset_payload = {}
        assets.each do |asset|
          asset_payload[File.basename(asset)] = url_for(asset)
        end
        payload['templates'] = templates_payload unless templates_payload.empty? && asset_payload.empty?
        payload['templates']['assets'] = JSON.dump(asset_payload) unless asset_payload.empty?
        payload
      end

      alias_method :ensure_manifest!, :manifest

      def javascript
        filename = theme_package_path('script.js')
        @javascript ||= File.read(filename) if File.exist?(filename)
      end

      def start_server
        require 'zendesk_apps_tools/theming/server'
        ZendeskAppsTools::Theming::Server.tap do |server|
          server.set :bind, options[:bind] if options[:bind]
          server.set :port, options[:port]
          server.set :root, app_dir
          server.set :public_folder, app_dir
          server.run!
        end
      end
    end
  end
end

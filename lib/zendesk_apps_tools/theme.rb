# frozen_string_literal: true

require 'zendesk_apps_tools/theming/common'
require 'thin'

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
                  desc: 'The role for the preview URL',
                  aliases: '-r'
    method_option :livereload, type: :boolean, default: true, desc: 'Enable or disable live-reloading the preview when a change is made.'
    def preview
      setup_path(options[:path])
      ensure_manifest!
      require 'faraday'
      full_upload
      callbacks_after_upload = []
      start_listener(callbacks_after_upload)
      start_server(callbacks_after_upload)
    end

    no_commands do
      def full_upload
        say_status 'Generating', 'Generating theme from local files'
        payload = generate_payload.merge(role: options[:role])
        say_status 'Generating', 'OK'
        say_status 'Uploading', 'Uploading theme'
        connection = get_connection(nil)
        connection.use Faraday::Response::RaiseError
        connection.put do |req|
          req.url '/hc/api/internal/theming/local_preview'
          req.body = JSON.dump(payload)
          req.headers['Content-Type'] = 'application/json'
        end
        say_status 'Uploading', 'OK'
        say_status 'Ready', "#{connection.url_prefix}hc/local_preview"
        say "To exit preview mode, visit: #{connection.url_prefix}hc/local_preview?finish"
      rescue Faraday::Error::ClientError => e
        say_status 'Uploading', "Failed: #{e.message}", :red
        begin
          broken_templates = JSON.parse(e.response[:body])['template_errors']
          broken_templates.each do |template_name, errors|
            errors.each do |error|
              say_status 'Error', "#{template_name} L#{error['line']}:#{error['column']}: #{error['description']}", :red
            end
          end
        rescue JSON::ParserError
          say_status 'Error', 'Server error 😭', :red
        end
      end

      def start_listener(callbacks_after_upload)
        # TODO: do we need to stop the listener at some point?
        require 'listen'
        path = Pathname.new(theme_package_path('.')).cleanpath
        listener = ::Listen.to(path, ignore: /\.zat/) do |modified, added, removed|
          need_upload = false
          if modified.any? { |file| file[/templates/] }
            need_upload = true
          end
          if added.any? || removed.any?
            need_upload = true
          end
          if need_upload
            full_upload
          end
          callbacks_after_upload.each do |callback|
            callback.call(modified.first || added.first || removed.first)
          end
        end
        listener.start
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

      def start_server(callbacks_after_upload)
        require 'zendesk_apps_tools/theming/server'
        if options[:livereload]
          require 'rack-livereload'
          require 'faye/websocket'
          Faye::WebSocket.load_adapter('thin')
        end

        ZendeskAppsTools::Theming::Server.tap do |server|
          server.set :bind, options[:bind] if options[:bind]
          server.set :port, options[:port]
          server.set :root, app_dir
          server.set :public_folder, app_dir
          server.set :livereload, options[:livereload]
          server.set :callbacks_after_load, callbacks_after_upload
          server.set :callback_map, {}
          server.use Rack::LiveReload, live_reload_port: 4567 if options[:livereload]
          server.run!
        end
      end
    end
  end
end

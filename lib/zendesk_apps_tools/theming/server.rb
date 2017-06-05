# frozen_string_literal: true

require 'sinatra/base'
require 'zendesk_apps_tools/theming/common'

module ZendeskAppsTools
  module Theming
    class Server < Sinatra::Base
      include Common

      get '/livereload' do
        if settings.livereload && Faye::WebSocket.websocket?(env)
          ws = Faye::WebSocket.new(env)

          new_callback = ->(filename) { ws.send(JSON.dump(command: 'reload', path: filename)) }
          settings.callback_map[ws] = new_callback
          settings.callbacks_after_load.push(new_callback)

          ws.onmessage = lambda do |event|
            message = JSON.parse(event.data)
            if message['command'] == 'hello'
              ws.send(JSON.dump(
                command: 'hello',
                protocols: [
                  'http://livereload.com/protocols/official-7',
                  'http://livereload.com/protocols/official-8',
                  'http://livereload.com/protocols/official-9',
                  'http://livereload.com/protocols/2.x-origin-version-negotiation',
                  'http://livereload.com/protocols/2.x-remote-control'
                ],
                serverName: 'ZAT LiveReload 2'
              ))
            end
          end

          ws.onclose = lambda do |event|
            settings.callbacks_after_load.delete_if do |entry|
              entry == settings.callback_map[ws]
            end
            settings.callback_map.delete ws
            ws = nil
          end

          # Return async Rack response
          ws.rack_response
        else
          [500, {}, 'Websocket Server Error']
        end
      end

      get '/guide/style.css' do
        content_type 'text/css'
        style_css = theme_package_path('style.css')
        raise Sinatra::NotFound unless File.exist?(style_css)
        zass_source = File.read(style_css)
        require 'zendesk_apps_tools/theming/zass_formatter'
        response = ZassFormatter.format(zass_source, settings_hash)
        response
      end

      get '/guide/*' do
        path = File.join(app_dir, *params[:splat])
        return send_file path if File.exist?(path)
        raise Sinatra::NotFound
      end

      def app_dir
        settings.root
      end

      def settings_hash
        manifest['settings'].flat_map { |setting_group| setting_group['variables'] }.each_with_object({}) do |variable, result|
          result[variable.fetch('identifier')] = value_for_setting(variable.fetch('type'), variable.fetch('value'))
        end
      end

      def value_for_setting(type, value)
        return value unless type == 'file'
        url_for(theme_package_path(value))
      end
    end
  end
end

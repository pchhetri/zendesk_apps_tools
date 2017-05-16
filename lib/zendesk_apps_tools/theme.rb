# frozen_string_literal: true

module ZendeskAppsTools
  class Theme < Thor
    include Thor::Actions
    include ZendeskAppsTools::CommandHelpers
    desc 'preview', 'Preview a theme in development'
    shared_options(except: %i[clean unattended])
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
      puts 'Preview!'
    end

    no_commands do
      def initial_upload
        payload = generate_payload
        connection = get_connection(nil)
        connection.put '/hc/api/internal/theming/local_preview', JSON.dump(payload)
      rescue Faraday::Error::ClientError => e
        say_error_and_exit e.message
      end

      def generate_payload
        payload = {}
        templates = Dir.glob(theme_package_path('templates', '*.hbs'))
        templates.each do |template|
          payload[File.basename(template, '.hbs')] = File.read(template)
        end
        assets = Dir.glob(theme_package_path('assets', '*'))
        asset_payload = {}
        assets.each do |asset|
          asset_payload[File.basename(asset)] = url_for(asset)
        end
        payload['assets'] = asset_payload unless asset_payload.empty?
        payload['js'] = url_for(theme_package_path('script.js')) if File.file?(theme_package_path('script.js'))
        payload['css'] = url_for(theme_package_path('style.css')) if File.file?(theme_package_path('style.css'))
        payload
      end

      def manifest
        full_manifest_path = theme_package_path('manifest.json')
        @manifest ||= JSON.parse(File.read(full_manifest_path))
      rescue Errno::ENOENT
        say_error_and_exit "There's no manifest file in #{full_manifest_path}"
      rescue JSON::ParserError
        say_error_and_exit "The manifest file is invalid at #{full_manifest_path}"
      end
      alias_method :ensure_manifest!, :manifest

      def javascript
        filename = theme_package_path('script.js')
        @javascript ||= File.read(filename) if File.exist?(filename)
      end

      def stylesheet_content
        style_css = theme_package_path('style.css')
        return nil unless File.exist?(style_css)
        zass_source = File.read(style_css)
        require 'zendesk_apps_tools/theming/zass_formatter'
        ZendeskAppsTools::Theming::ZassFormatter.format(zass_source, settings_hash)
      end

      def theme_package_path(*file)
        File.expand_path(File.join(app_dir, *file))
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

      def url_for(package_file)
        relative_path = Pathname.new(package_file).relative_path_from(Pathname.new(File.expand_path(app_dir))).cleanpath
        path_parts = recursive_pathname_split(relative_path)
        path_parts.shift
        "http://localhost:4567/guide/#{path_parts.join('/')}"
      end

      def recursive_pathname_split(relative_path)
        split_path = relative_path.split
        joined_directories = split_path[0]
        return split_path if split_path[0] == joined_directories.split[0]
        [*recursive_pathname_split(joined_directories), split_path[1]]
      end
    end
  end
end

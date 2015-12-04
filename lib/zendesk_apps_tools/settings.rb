require 'zendesk_apps_tools/common'
require 'yaml'

module ZendeskAppsTools
  class Settings
    def get_settings_from_user_input(user_input, parameters)
      return {} if parameters.nil?

      parameters.inject({}) do |settings, param|
        if param['default']
          input = user_input.get_value_from_stdin("Enter a value for parameter '#{param['name']}' or press 'Return' to use the default value '#{param['default']}':\n", allow_empty: true)
          input = param['default'] if input.empty?
        elsif param['required']
          input = user_input.get_value_from_stdin("Enter a value for required parameter '#{param['name']}':\n")
        else
          input = user_input.get_value_from_stdin("Enter a value for optional parameter '#{param['name']}' or press 'Return' to skip:\n", allow_empty: true)
          input = nil if input.empty?
        end

        if param['type'] == 'checkbox'
          input = convert_to_boolean_for_checkbox(input)
        end

        settings[param['name']] = input if input != ''
        settings
      end
    end

    def find_settings_file(path)
      try_paths = ['./', '../', 'settings/', '../settings/']

      try_paths.reduce([]) do | memo, try_path |
        memo << File.join(path, try_path, 'settings.yml')
        memo << File.join(path, try_path, 'settings.json')
      end.find do |settings_file|
        File.exists?(settings_file)
      end
    end

    def get_settings_from_file(filepath, parameters, domain = false)
      return {} if parameters.nil?
      return nil unless File.exist? filepath

      begin
        settings_file = File.read(filepath)

        if filepath =~ /\.json$/ || settings_file =~ /\A\s*{/
          settings_data = JSON.load(settings_file)
        else
          settings_data = YAML.load(settings_file)
        end

        settings_data = settings_data[domain] if settings_data[domain] && domain

        settings_data.each do |index, setting|
          if setting.is_a?(Hash) || setting.is_a?(Array)
            settings_data[index] = JSON.dump(setting)
          end
        end
      rescue => err
        puts "Failed to load #{filepath}"
        puts err.message
        return nil
      end

      parameters.inject({}) do |settings, param|
        input = settings_data[param['name']]

        if !input && param['default']
          input = param['default']
        end

        if !input && param['required']
          puts "\e[0;31m'#{param['name']}' is required but not specified in the config file.\e[0m\n"
          return {}
        end

        if param['type'] == 'checkbox'
          input = convert_to_boolean_for_checkbox(input)
        end

        settings[param['name']] = input if input != ''
        settings
      end
    end

    private

    def convert_to_boolean_for_checkbox(input)
      unless [TrueClass, FalseClass].include?(input.class)
        return (input =~ /^(true|t|yes|y|1)$/i) ? true : false
      end
      input
    end
  end
end

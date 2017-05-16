module ZendeskAppsTools
  module Theming
    module Common
      def theme_package_path(*file)
        File.expand_path(File.join(app_dir, *file))
      end

      def url_for(package_file)
        relative_path = relative_path_for(package_file)
        path_parts = recursive_pathname_split(relative_path)
        path_parts.shift
        "http://localhost:4567/guide/#{path_parts.join('/')}"
      end

      def relative_path_for(filename)
        Pathname.new(filename).relative_path_from(Pathname.new(File.expand_path(app_dir))).cleanpath
      end

      def manifest
        full_manifest_path = theme_package_path('manifest.json')
        @manifest ||= JSON.parse(File.read(full_manifest_path))
      rescue Errno::ENOENT
        say_error_and_exit "There's no manifest file in #{full_manifest_path}"
      rescue JSON::ParserError
        say_error_and_exit "The manifest file is invalid at #{full_manifest_path}"
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

Gem::Specification.new do |s|
  s.name        = 'xat'
  s.version     = '1.32.0'
  s.executables << 'xat'
  s.platform    = Gem::Platform::RUBY
  s.license     = 'Apache License Version 2.0'
  s.authors     = ['Olaf Kwant']
  s.email       = ['okwant@zendesk.com']
  s.homepage    = 'https://github.com/ocke/xat'
  s.summary     = 'Tools to help you develop Zendesk Apps.'
  s.description = s.summary

  s.required_ruby_version = '>= 2.0'
  s.required_rubygems_version = '>= 1.3.6'

  s.add_runtime_dependency 'thor',        '~> 0.18.1'
  s.add_runtime_dependency 'rubyzip',     '~> 0.9.1'
  s.add_runtime_dependency 'sinatra',     '~> 1.4.6'
  s.add_runtime_dependency 'faraday',     '~> 0.9.2'
  s.add_runtime_dependency 'zendesk_apps_support', '~> 1.28'

  s.add_development_dependency 'cucumber'
  s.add_development_dependency 'aruba'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'bump'
  s.add_development_dependency 'webmock'

  s.files        = Dir.glob('{bin,lib,app_template*,templates}/**/*') + %w(README.md LICENSE)
  s.test_files   = Dir.glob('features/**/*')
  s.require_path = 'lib'
end

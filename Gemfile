source 'https://rubygems.org'

gemspec

gem 'activerecord-jdbcpostgresql-adapter', '>= 1.3.1', platform: :jruby
gem 'lint-config-cc', git: 'https://github.com/Casecommons/lint-config-ruby.git', ref: 'fba62703d2743ac260b0dc55f6cfa9e9163c9a6f'
gem 'pg', platform: :ruby

if ENV['ACTIVE_RECORD_BRANCH']
  gem 'activerecord', git: 'https://github.com/rails/rails.git', branch: ENV['ACTIVE_RECORD_BRANCH']
  gem 'arel', git: 'https://github.com/rails/arel.git' if ENV['ACTIVE_RECORD_BRANCH'] == 'master'
end

if ENV['ACTIVE_RECORD_VERSION']
  gem 'activerecord', ENV['ACTIVE_RECORD_VERSION']
end

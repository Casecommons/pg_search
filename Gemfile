source 'https://rubygems.org'

gemspec

gem 'pg', :platform => :ruby
gem "activerecord-jdbcpostgresql-adapter", ">= 1.3.1", :platform => :jruby

if ENV['ACTIVE_RECORD_BRANCH']
  gem 'activerecord', :git => 'https://github.com/rails/rails.git', :branch => ENV['ACTIVE_RECORD_BRANCH']
  gem 'arel', :git => 'https://github.com/rails/arel.git' if ENV['ACTIVE_RECORD_BRANCH'] == 'master'
end

if ENV['ACTIVE_RECORD_VERSION']
  gem 'activerecord', ENV['ACTIVE_RECORD_VERSION']
end

group :development do
  gem 'guard-rspec', :require => false
  gem 'rb-inotify', :require => false
  gem 'rb-fsevent', :require => false
  gem 'rb-fchange', :require => false
end

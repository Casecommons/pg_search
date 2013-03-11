source "http://rubygems.org"

gemspec

gem "rake"
gem "rdoc"
gem "pry"

platforms :ruby do
  gem 'pg'
end

platforms :jruby do
  gem "activerecord-jdbcpostgresql-adapter"
end

gem "rspec"
gem "with_model"

gem "activerecord", "~> #{ENV["ACTIVE_RECORD_VERSION"]}.0" if ENV["ACTIVE_RECORD_VERSION"]

gem 'coveralls', require: false

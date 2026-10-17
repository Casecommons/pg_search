# frozen_string_literal: true

source "https://rubygems.org", cooldown: 7

gemspec

gem "pg", ">= 0.21.0", platform: :ruby
gem "activerecord-jdbcpostgresql-adapter", ">= 1.3.1", platform: :jruby

if ENV["ACTIVE_RECORD_BRANCH"]
  gem "activerecord", git: "https://github.com/rails/rails.git", branch: ENV.fetch("ACTIVE_RECORD_BRANCH", nil)
  gem "arel", git: "https://github.com/rails/arel.git" if ENV.fetch("ACTIVE_RECORD_BRANCH", nil) == "master"
end

if ENV["ACTIVE_RECORD_VERSION"]
  active_record_version = ENV.fetch("ACTIVE_RECORD_VERSION")
  gem "activerecord", active_record_version # standard:disable Bundler/DuplicatedGem

  # Active Record 8.0.5.1 passes the quirks_mode option that json 3 rejects.
  # 8-0-stable fixed it in rails/rails@2786de2; drop this pin once an 8.0
  # release ships it.
  gem "json", "< 3" if Gem::Requirement.new(active_record_version).satisfied_by?(Gem::Version.new("8.0.5.1"))
end

gem "benchmark"
gem "debug"
gem "irb"
gem "mutex_m"
gem "rake"
gem "rspec"
gem "ruby-lsp"
gem "simplecov"
gem "simplecov-lcov"
gem "standard", require: false
gem "standard-rails", require: false
gem "standard-rspec", require: false
gem "warning"
gem "with_model"

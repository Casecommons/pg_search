# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'pg_search/version'

Gem::Specification.new do |s|
  s.name        = 'pg_search'
  s.version     = PgSearch::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Grant Hutchins', 'Case Commons, LLC']
  s.email       = %w[gems@nertzy.com casecommons-dev@googlegroups.com]
  s.homepage    = 'https://github.com/Casecommons/pg_search'
  s.summary     = "PgSearch builds Active Record named scopes that take advantage of PostgreSQL's full text search"
  s.description = "PgSearch builds Active Record named scopes that take advantage of PostgreSQL's full text search"
  s.licenses    = ['MIT']

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ['lib']

  s.add_dependency 'activerecord', '>= 4.2'
  s.add_dependency 'activesupport', '>= 4.2'

  s.add_development_dependency 'codeclimate-test-reporter'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '>= 3.3'
  s.add_development_dependency 'rubocop', '>= 0.63.0'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'with_model', '>= 1.2'

  s.required_ruby_version = '>= 2.3'
end

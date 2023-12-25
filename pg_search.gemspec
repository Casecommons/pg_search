# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "pg_search/version"

Gem::Specification.new do |s|
  s.name = "pg_search"
  s.version = PgSearch::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Grant Hutchins", "Case Commons, LLC"]
  s.email = %w[gems@nertzy.com casecommons-dev@googlegroups.com]
  s.homepage = "https://github.com/Casecommons/pg_search"
  s.summary = "PgSearch builds Active Record named scopes that take advantage of PostgreSQL's full text search"
  s.description = "PgSearch builds Active Record named scopes that take advantage of PostgreSQL's full text search"
  s.licenses = ["MIT"]
  s.metadata["rubygems_mfa_required"] = "true"

  s.files = `git ls-files -z`.split("\x0")
  s.require_paths = ["lib"]

  s.add_dependency "activerecord", ">= 6.1"
  s.add_dependency "activesupport", ">= 6.1"

  s.required_ruby_version = ">= 3.0"
end

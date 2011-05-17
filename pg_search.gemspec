# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pg_search/version"

Gem::Specification.new do |s|
  s.name        = "pg_search"
  s.version     = PgSearch::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Case Commons, LLC"]
  s.email       = ["casecommons-dev@googlegroups.com"]
  s.homepage    = "https://github.com/Casecommons/pg_search"
  s.summary     = %q{PgSearch builds ActiveRecord named scopes that take advantage of PostgreSQL's full text search}
  s.description = %q{PgSearch builds ActiveRecord named scopes that take advantage of PostgreSQL's full text search}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'activerecord', '>=3'
  s.add_dependency 'activesupport', '>=3'
end

require "active_record"
require "pg_search/configuration"
require "pg_search/features"
require "pg_search/normalizer"
require "pg_search/scope"
require "pg_search/scope_options"
require "pg_search/version"
require "active_support/concern"
#require "pg_search/railtie" if defined?(Rails) && defined?(Rails::Railtie)

module PgSearch
  extend ActiveSupport::Concern

  module ClassMethods
    def pg_search_scope(name, options)
      self.scope(
        name,
        PgSearch::Scope.new(name, self, options).to_proc
      )
    end
  end

  module InstanceMethods
    def rank
      attributes['pg_search_rank'].to_f
    end
  end
end

require "active_record"
require "pg_search/configuration"
require "pg_search/features"
require "pg_search/normalizer"
require "pg_search/scope"
require "pg_search/scope_options"
require "pg_search/version"
#require "pg_search/railtie" if defined?(Rails) && defined?(Rails::Railtie)

module PgSearch
  def self.included(base)
    base.send(:extend, ClassMethods)
  end

  module ClassMethods
    def pg_search_scope(name, options)
      scope = PgSearch::Scope.new(name, self, options)
      scope_method =
        if respond_to?(:scope) && !protected_methods.include?('scope')
          :scope # ActiveRecord 3.x
        else
          :named_scope # ActiveRecord 2.x
        end

      send(scope_method, name, scope.to_proc)
    end
  end

  def rank
    attributes['pg_search_rank'].to_f
  end
end

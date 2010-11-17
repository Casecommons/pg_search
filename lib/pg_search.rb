require "active_record"
require "pg_search/scope"
require "pg_search/scope_options"

module PgSearch
  def self.included(base)
    base.send(:extend, ClassMethods)
  end

  module ClassMethods
    def pg_search_scope(name, options)
      scope = PgSearch::Scope.new(name, options, self)
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

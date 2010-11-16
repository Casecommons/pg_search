require "active_record"
require "pg_search/scope_options"

module PgSearch
  def self.included(base)
    base.send(:extend, ClassMethods)
  end

  class Scope
    def initialize(name, scope_options_or_proc, model)
      @name = name
      @model = model
      @options_proc = build_options_proc(scope_options_or_proc)
    end

    def to_proc
      lambda { |*args|
        ScopeOptions.new(@name, @options_proc, @model, args).to_hash
      }
    end

    private

    def build_options_proc(scope_options_or_proc)
      case scope_options_or_proc
        when Proc
          scope_options_or_proc
        when Hash
          lambda do |query|
            scope_options_or_proc.reverse_merge(
              :query => query
            )
          end
        else
          raise ArgumentError, "A PgSearch scope expects a Proc or Hash for its options"
      end
    end
  end


  module ClassMethods
    def pg_search_scope(name, options)
      scope = PgSearch::Scope.new(name, options, self)
      scope_method = if respond_to?(:scope) && !protected_methods.include?('scope')
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

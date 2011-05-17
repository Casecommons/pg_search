module PgSearch
  class Scope
    def initialize(name, model, scope_options_or_proc)
      @name = name
      @model = model
      @options_proc = build_options_proc(scope_options_or_proc)
    end

    def to_proc
      lambda { |*args|
        config = Configuration.new(@options_proc.call(*args), @model)
        ScopeOptions.new(@name, @model, config).to_relation
      }
    end

    private

    def build_options_proc(scope_options_or_proc)
      case scope_options_or_proc
        when Proc
          scope_options_or_proc
        when Hash
          lambda { |query|
            scope_options_or_proc.reverse_merge(:query => query)
          }
        else
          raise ArgumentError, "A PgSearch scope expects a Proc or Hash for its options"
      end
    end
  end
end

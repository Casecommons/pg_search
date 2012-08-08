module PgSearch
  class Scope
    def initialize(name, model, scope_options_or_proc)
      @name = name
      @model = model
      @options_proc = build_options_proc(scope_options_or_proc)
    end

    def build_relation(*args)
      config = Configuration.new(@options_proc.call(*args), @model)
      scope_options = ScopeOptions.new(@name, config)
      scope_options.apply(@model)
    end

    private

    def build_options_proc(scope_options)
      return scope_options if scope_options.respond_to?(:call)

      unless scope_options.respond_to?(:merge)
        raise ArgumentError, "pg_search_scope expects a Hash or Proc"
      end

      lambda { |query| {:query => query}.merge(scope_options) }
    end
  end
end

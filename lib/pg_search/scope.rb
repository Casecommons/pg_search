module PgSearch
  class Scope
    attr_reader :options_proc

    def initialize(scope_options_or_proc)
      @options_proc = build_options_proc(scope_options_or_proc)
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

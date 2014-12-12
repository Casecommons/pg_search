module PgSearch
  class Normalizer
    def initialize(config)
      @config = config
    end

    def add_normalization(sql_expression) # rubocop:disable Metrics/AbcSize
      return sql_expression unless config.ignore.include?(:accents)

      if config.postgresql_version < 90000
        raise PgSearch::NotSupportedForPostgresqlVersion.new(<<-MESSAGE.strip_heredoc)
          Sorry, {:ignoring => :accents} only works in PostgreSQL 9.0 and above.
          #{config.inspect}
        MESSAGE
      end

      sql_node = case sql_expression
                 when Arel::Nodes::Node
                   sql_expression
                 else
                   Arel.sql(sql_expression)
                 end

      Arel::Nodes::NamedFunction.new(
        PgSearch.unaccent_function,
        [sql_node]
      ).to_sql
    end

    private

    attr_reader :config
  end
end

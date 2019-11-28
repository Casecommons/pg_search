# frozen_string_literal: true

module PgSearch
  class Normalizer
    def initialize(config)
      @config = config
    end

    def add_normalization(sql_expression)
      return sql_expression if (config.ignore & %i[accents white_spaces]).empty?

      sql_node = case sql_expression
                 when Arel::Nodes::Node
                   sql_expression
                 else
                   Arel.sql(sql_expression)
                 end

      sql_node = ignore_accents(sql_node) if ignore?(:accents)
      sql_node = ignore_white_spaces(sql_node) if ignore?(:white_spaces)

      sql_node.to_sql
    end

    private

    attr_reader :config

    def ignore?(option)
      config.ignore.include?(option)
    end

    def ignore_accents(sql_node)
      Arel::Nodes::NamedFunction.new(
        PgSearch.unaccent_function,
        [sql_node]
      )
    end

    def ignore_white_spaces(sql_node)
      Arel::Nodes::NamedFunction.new(
        PgSearch.replace_function,
        [sql_node, Arel.sql("' ', ''")]
      )
    end
  end
end

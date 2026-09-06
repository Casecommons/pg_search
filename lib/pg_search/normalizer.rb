# frozen_string_literal: true

module PgSearch
  class Normalizer
    def initialize(config)
      @config = config
    end

    DISALLOWED_CHARACTERS = "'[''?\\:]'"

    def add_normalization(expression)
      node = to_node(expression)
      return node unless config.ignore.include?(:accents)

      Arel::Nodes::NamedFunction.new(
        "regexp_replace",
        [
          Arel::Nodes::NamedFunction.new(PgSearch.unaccent_function, [node]),
          Arel.sql(DISALLOWED_CHARACTERS),
          Arel.sql("''"),
          Arel.sql("'g'")
        ]
      )
    end

    private

    attr_reader :config

    def to_node(expression)
      case expression
      when Arel::Nodes::Node
        expression
      else
        Arel.sql(expression.to_s)
      end
    end
  end
end

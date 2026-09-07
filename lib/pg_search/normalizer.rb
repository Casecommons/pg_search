# frozen_string_literal: true

module PgSearch
  class Normalizer
    # Arguments
    #
    # +config+:: Search configuration whose ignore list controls accent
    #            normalization.
    def initialize(config)
      @config = config
    end

    DISALLOWED_CHARACTERS = "['?\\:]"

    # Applies configured accent normalization, preserving the input expression
    # without an unaccent wrapper when accents are not ignored.
    #
    # Arguments
    #
    # +expression+:: An Arel node, attribute, or trusted SQL String. A String is
    #                an SQL expression, not a value to quote.
    #
    # Returns a composable Arel expression.
    #
    # Raises
    #
    # TypeError:: If +expression+ is not an Arel node, attribute, or String.
    def add_normalization(expression)
      node = to_node(expression)
      return node unless config.ignore.include?(:accents)

      Arel::Nodes::NamedFunction.new(
        "regexp_replace",
        [
          Arel::Nodes::NamedFunction.new(PgSearch.unaccent_function, [node]),
          Arel::Nodes.build_quoted(DISALLOWED_CHARACTERS),
          Arel::Nodes.build_quoted(""),
          Arel::Nodes.build_quoted("g")
        ]
      )
    end

    private

    attr_reader :config

    def to_node(expression)
      case expression
      when Arel::Nodes::Node, Arel::Attributes::Attribute
        expression
      when String
        Arel.sql(expression)
      else
        raise TypeError
      end
    end
  end
end

# frozen_string_literal: true

module PgSearch
  class Normalizer
    def initialize(config)
      @config = config
    end

    def add_normalization(node)
      return node unless config.ignore.include?(:accents)

      Arel::Nodes::NamedFunction.new(
        PgSearch.unaccent_function,
        [node]
      )
    end

    private

    attr_reader :config
  end
end

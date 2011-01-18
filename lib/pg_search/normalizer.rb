module PgSearch
  class Normalizer
    def initialize(config)
      @config = config
    end

    def add_normalization(original_sql)
      normalized_sql = original_sql
      normalized_sql = "unaccent(#{normalized_sql})" if @config.ignore.include?(:accents)
      normalized_sql
    end
  end
end

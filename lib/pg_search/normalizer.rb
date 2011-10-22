module PgSearch
  class Normalizer
    def initialize(config)
      @config = config
    end

    def add_normalization(original_sql)
      normalized_sql = original_sql
      if @config.ignore.include?(:accents)
        if @config.postgresql_version < 90000
          raise PgSearch::NotSupportedForPostgresqlVersion.new(<<-MESSAGE.gsub /^\s*/, '')
          Sorry, {:ignoring => :accents} only works in PostgreSQL 9.0 and above.
          #{@config.inspect}
          MESSAGE
        else
          normalized_sql = "unaccent(#{normalized_sql})"
        end
      end
      normalized_sql
    end
  end
end

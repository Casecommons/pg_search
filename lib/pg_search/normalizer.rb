module PgSearch
  class Normalizer
    def initialize(config)
      @config = config
    end

    def add_normalization(sql_expression)
      if @config.ignore.include?(:accents)
        if @config.postgresql_version < 90000
          raise PgSearch::NotSupportedForPostgresqlVersion.new(<<-MESSAGE.gsub /^\s*/, '')
            Sorry, {:ignoring => :accents} only works in PostgreSQL 9.0 and above.
            #{@config.inspect}
          MESSAGE
        else
          "unaccent(#{sql_expression})"
        end
      else
        sql_expression
      end
    end
  end
end

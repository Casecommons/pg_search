require "active_support/core_ext/module/delegation"

module PgSearch
  class ScopeOptions
    attr_reader :model

    delegate :connection, :quoted_table_name, :sanitize_sql_array, :primary_key, :to => :model

    def initialize(name, model, config)
      @name = name
      @model = model
      @config = config
    end

    def to_hash
      {
        :select => "#{quoted_table_name}.*, (#{rank}) AS pg_search_rank",
        :conditions => [conditions, interpolations],
        :order => "pg_search_rank DESC, #{quoted_table_name}.#{connection.quote_column_name(primary_key)} ASC"
      }
    end

    private

    def columns_with_weights
      @config.search_columns.map do |column_name, weight|
        ["coalesce(#{quoted_table_name}.#{connection.quote_column_name(column_name)}, '')",
         weight]
      end
    end

    def document
      columns_with_weights.map { |column, *| column }.join(" || ' ' || ")
    end

    def add_normalization(original_sql)
      normalized_sql = original_sql
      normalized_sql = "unaccent(#{normalized_sql})" if @config.normalizations.include?(:diacritics)
      normalized_sql
    end

    def tsquery
      @config.query.split(" ").compact.map do |term|
        term = term.gsub(/['?]/, " ")
        term = "'#{term}'"
        term = "#{term}:*" if @config.normalizations.include?(:prefixes)
        "to_tsquery(#{":dictionary," if @config.dictionary} #{add_normalization(connection.quote(term))})"
      end.join(" && ")
    end

    def tsdocument
      columns_with_weights.map do |column, weight|
        tsvector = "to_tsvector(#{":dictionary," if @config.dictionary} #{add_normalization(column)})"
        weight.nil? ? tsvector : "setweight(#{tsvector}, #{connection.quote(weight)})"
      end.join(" || ")
    end

    def conditions
      conditions_hash = {
        :tsearch => "(#{tsdocument}) @@ (#{tsquery})",
        :trigram => "(#{add_normalization(document)}) % #{add_normalization(":query")}"
      }

      @config.features.map do |feature|
        "(#{conditions_hash[feature]})"
      end.join(" OR ")
    end

    def interpolations
      {
        :query => @config.query,
        :dictionary => @config.dictionary.to_s
      }
    end

    def tsearch_rank
      sanitize_sql_array(["ts_rank((#{tsdocument}), (#{tsquery}))", interpolations])
    end

    def rank
      (@config.ranking_sql || ":tsearch_rank").gsub(':tsearch_rank', tsearch_rank)
    end
  end
end

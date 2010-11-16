module PgSearch
  class ScopeOptions
    extend ActiveSupport::Memoizable
    attr_reader :model

    delegate :connection, :quoted_table_name, :sanitize_sql_array, :primary_key, :to => :model

    def initialize(name, options_proc, model, args)
      @name = name
      @options_proc = options_proc
      @model = model
      @args = args
    end

    def pg_search_options
      @options_proc.call(*@args).reverse_merge(default_options()).tap { |options| assert_valid_options(options) }
    end
    memoize :pg_search_options

    def to_hash
      query = pg_search_options[:query].to_s
      normalizing = Array.wrap(pg_search_options[:normalizing])
      dictionary = pg_search_options[:with_dictionary]

      raise ArgumentError, "the search scope #{@name} must have :against in its options" unless pg_search_options[:against]

      against = pg_search_options[:against]
      against = Array.wrap(against) unless against.is_a?(Hash)

      columns_with_weights = against.map do |column_name, weight|
        ["coalesce(#{quoted_table_name}.#{connection.quote_column_name(column_name)}, '')",
         weight]
      end

      document = columns_with_weights.map { |column, *| column }.join(" || ' ' || ")

      normalized = lambda do |string|
        string = "unaccent(#{string})" if normalizing.include?(:diacritics)
        string
      end

      tsquery = query.split(" ").compact.map do |term|
        term = term.gsub("'", " ")
        term = "'#{term}'"
        term = "#{term}:*" if normalizing.include?(:prefixes)
        "to_tsquery(#{":dictionary," if dictionary} #{normalized[connection.quote(term)]})"
      end.join(" && ")

      tsdocument = columns_with_weights.map do |column, weight|
        tsvector = "to_tsvector(#{":dictionary," if dictionary} #{normalized[column]})"
        weight.nil? ? tsvector : "setweight(#{tsvector}, #{connection.quote(weight)})"
      end.join(" || ")

      conditions_hash = {
        :tsearch => "(#{tsdocument}) @@ (#{tsquery})",
        :trigram => "(#{normalized[document]}) % #{normalized[":query"]}"
      }

      conditions = Array.wrap(pg_search_options[:using]).map do |feature|
        "(#{conditions_hash[feature]})"
      end.join(" OR ")

      interpolations = {
        :query => query,
        :dictionary => dictionary.to_s
      }

      tsearch_rank = sanitize_sql_array(["ts_rank((#{tsdocument}), (#{tsquery}))", interpolations])

      pg_search_rank = pg_search_options[:ranked_by] || ":tsearch_rank"
      pg_search_rank = pg_search_rank.gsub(':tsearch_rank', tsearch_rank)

      {
        :select => "#{quoted_table_name}.*, (#{pg_search_rank}) AS pg_search_rank",
        :conditions => [conditions, interpolations],
        :order => "pg_search_rank DESC, #{quoted_table_name}.#{connection.quote_column_name(primary_key)} ASC"
      }
    end

    private

    def default_options
      {:using => :tsearch}
    end

    def assert_valid_options(options)
      options.assert_valid_keys(:against, :ranked_by, :normalizing, :with_dictionary, :using, :query)

      {
        :using => [:trigram, :tsearch],
        :normalizing => [:prefixes, :diacritics]
      }.each do |key, valid_values|
        Array.wrap(options[key]).each do |value|
          unless valid_values.include?(value)
            raise ArgumentError, ":#{key} cannot accept #{value}"
          end
        end
      end
    end
  end
end

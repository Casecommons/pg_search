require "active_support/core_ext/module/delegation"

module PgSearch
  module Features
    class DMetaphone
      delegate :connection, :quoted_table_name, :sanitize_sql_array, :primary_key, :to => :'@model'
      delegate :conditions, :rank, :to => :'@tsearch'

      # config is temporary as we refactor
      def initialize(query, options, config, model, interpolations, normalizer)
        dmetaphone_normalizer = Normalizer.new(normalizer)
        @tsearch = TSearch.new(query, options, config, model, interpolations, dmetaphone_normalizer)
      end

      # Decorates a normalizer with dmetaphone processing.
      class Normalizer
        def initialize(normalizer_to_wrap)
          @decorated_normalizer = normalizer_to_wrap
        end

        def add_normalization(original_sql)
          otherwise_normalized_sql = @decorated_normalizer.add_normalization(original_sql)
          "array_to_string(ARRAY(SELECT dmetaphone(unnest(regexp_split_to_array(#{otherwise_normalized_sql}, E'\\s+')))), ' ')"
        end
      end
    end
  end
end

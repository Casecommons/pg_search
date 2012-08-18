module PgSearch
  module Features
    class DMetaphone
      def initialize(query, options, columns, model, normalizer)
        dmetaphone_normalizer = Normalizer.new(normalizer)
        options = (options || {}).merge(:dictionary => 'simple')
        @tsearch = TSearch.new(query, options, columns, model, dmetaphone_normalizer)
      end

      def conditions
        @tsearch.conditions
      end

      def rank
        @tsearch.rank
      end

      # Decorates a normalizer with dmetaphone processing.
      class Normalizer
        def initialize(normalizer_to_wrap)
          @decorated_normalizer = normalizer_to_wrap
        end

        def add_normalization(original_sql)
          otherwise_normalized_sql = @decorated_normalizer.add_normalization(original_sql)
          "pg_search_dmetaphone(#{otherwise_normalized_sql})"
        end
      end
    end
  end
end

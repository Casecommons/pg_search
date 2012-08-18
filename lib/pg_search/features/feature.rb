module PgSearch
  module Features
    class Feature
      def initialize(query, options, columns, model, normalizer)
        @query = query
        @options = options || {}
        @columns = columns
        @model = model
        @normalizer = normalizer
      end

      private

      def document
        if @columns.length == 1
          @columns.first.to_sql
        else
          expressions = @columns.map { |column| column.to_sql }.join(", ")
          "array_to_string(ARRAY[#{expressions}], ' ')"
        end
      end

      def normalize(expression)
        @normalizer.add_normalization(expression)
      end
    end
  end
end

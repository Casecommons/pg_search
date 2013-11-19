module PgSearch
  module Features
    class Trigram < Feature
      def conditions
        Arel::Nodes::Grouping.new(
          Arel::Nodes::InfixOperation.new("%", normalized_document, normalized_query)
        )
      end

      def rank
        Arel::Nodes::Grouping.new(
          Arel::Nodes::NamedFunction.new(
            "similarity",
            [
              normalized_document,
              normalized_query
            ]
          )
        )
      end

      private

      def normalized_document
        Arel::Nodes::Grouping.new(Arel.sql(normalize(document)))
      end

      def normalized_query
        sanitized_query = connection.quote(query)
        Arel.sql(normalize(sanitized_query))
      end
    end
  end
end

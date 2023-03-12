module PgSearch
  module Features
    class ILike < Feature
      def conditions
        Arel::Nodes::Grouping.new(
          Arel::Nodes::InfixOperation.new(
            'ILIKE',
            normalized_document,
            normalized_query
          )
        )
      end

      def rank
        Arel::Nodes::Grouping.new(Arel.sql('0')) # no ranking or delegate to tsearch like DMetaphone?
      end

      private

      def normalized_query
        Arel.sql(connection.quote("%#{query}%"))
      end

      def normalized_document
        Arel::Nodes::Grouping.new(Arel.sql(document))
      end
    end
  end
end

module PgSearch
  module Features
    class Trigram < Feature
      def conditions
        Arel::Nodes::Grouping.new(
          Arel::Nodes::InfixOperation.new("%", arel_wrap(document), query)
        )
      end

      def rank
        arel_wrap(
          "similarity((#{normalize(document)}), #{normalize(":query")})",
          :query => query
        )
      end
    end
  end
end

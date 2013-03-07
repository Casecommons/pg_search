module PgSearch
  module Features
    class Trigram < Feature
      def conditions
        Arel::Nodes::Grouping.new(
          Arel::Nodes::InfixOperation.new("%", arel_wrap(document), query)
        )
      end

      def rank
        [
          "similarity((#{normalize(document)}), #{normalize(":query")})",
          {:query => query}
        ]
      end
    end
  end
end

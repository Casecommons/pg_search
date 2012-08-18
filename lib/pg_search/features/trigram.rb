module PgSearch
  module Features
    class Trigram < Feature
      def conditions
        [
          "(#{normalize(document)}) % #{normalize(":query")}",
          {:query => @query}
        ]
      end

      def rank
        [
          "similarity((#{normalize(document)}), #{normalize(":query")})",
          {:query => @query}
        ]
      end
    end
  end
end

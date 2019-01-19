# frozen_string_literal: true

module PgSearch
  module Features
    class Trigram < Feature
      def self.valid_options
        super + [:threshold]
      end

      def conditions
        if options[:threshold]
          Arel::Nodes::Grouping.new(
            similarity.gteq(options[:threshold])
          )
        else
          Arel::Nodes::Grouping.new(
            Arel::Nodes::InfixOperation.new("%", normalized_document, normalized_query)
          )
        end
      end

      def rank
        Arel::Nodes::Grouping.new(similarity)
      end

      private

      def similarity
        Arel::Nodes::NamedFunction.new(
          "similarity",
          [
            normalized_document,
            normalized_query
          ]
        )
      end

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

# frozen_string_literal: true

require 'digest'

module PgSearch
  class Configuration
    class Column
      attr_reader :weight, :tsvector_column, :name

      def initialize(column_name, weight, model)
        @name = column_name.to_s
        @column_name = column_name.to_s
        if weight.is_a?(Hash)
          @weight = weight[:weight]
          @tsvector_column = weight[:tsvector_column]
        else
          @weight = weight
        end
        @model = model
        @connection = model.connection
      end

      def full_name
        "#{table_name}.#{column_name}"
      end

      def to_sql
        if tsvector_column
          "coalesce(#{expression}, '')"
        else
          "coalesce(#{expression}::text, '')"
        end
      end

      private

      def table_name
        @model.quoted_table_name
      end

      def column_name
        @connection.quote_column_name(@column_name)
      end

      def expression
        full_name
      end
    end
  end
end

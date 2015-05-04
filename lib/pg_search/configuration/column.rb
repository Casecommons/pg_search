# frozen_string_literal: true

require 'digest'

module PgSearch
  class Configuration
    class Column
      attr_reader :weight, :tsvector_column, :name

      def initialize(column_name, options, model)
        @name = column_name.to_s
        @column_name = column_name.to_s
        @model = model
        @connection = model.connection
        if options.is_a?(Hash)
          @weight = options[:weight]
          @tsvector_column = options[:tsvector_column]
        else
          @weight = options
        end
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

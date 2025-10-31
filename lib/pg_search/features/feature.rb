# frozen_string_literal: true

require "active_support/core_ext/module/delegation"
require "active_support/core_ext/hash/keys"

module PgSearch
  module Features
    class Feature
      def self.valid_options
        %i[only sort_only]
      end

      delegate :connection, :quoted_table_name, to: :@model

      def initialize(query, options, all_columns, model, normalizer)
        @query = query
        @options = (options || {}).assert_valid_keys(self.class.valid_options)
        @all_columns = all_columns
        @model = model
        @normalizer = normalizer
      end

      private

      attr_reader :query, :options, :all_columns, :model, :normalizer

      def document
        column_expressions = columns.map do |column|
          # Get the coalesce expression as an Arel node from Column#to_arel
          column.to_arel
        end

        # Combine with || operator using Arel InfixOperation
        if column_expressions.empty?
          Arel::Nodes::Quoted.new("")
        elsif column_expressions.size == 1
          column_expressions.first
        else
          # Join with ' ' || ' ' pattern
          column_expressions.inject do |memo, expr|
            space_literal = Arel::Nodes::Quoted.new(" ")
            memo_with_space = Arel::Nodes::InfixOperation.new("||", memo, space_literal)
            Arel::Nodes::InfixOperation.new("||", memo_with_space, expr)
          end
        end
      end

      def columns
        if options[:only]
          all_columns.select do |column|
            Array.wrap(options[:only]).map(&:to_s).include? column.name
          end
        else
          all_columns
        end
      end

      def normalize(expression)
        normalizer.add_normalization(expression)
      end
    end
  end
end

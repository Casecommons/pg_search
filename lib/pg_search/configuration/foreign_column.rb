# frozen_string_literal: true

require "digest"

module PgSearch
  class Configuration
    class ForeignColumn < Column
      attr_reader :weight

      def initialize(column_name, weight, model, association)
        super(column_name, weight, model)
        @association = association
      end

      def alias
        Configuration.alias(@association.subselect_alias, @column_name)
      end

      private

      def attribute
        @model.arel_table.alias(@association.subselect_alias)[self.alias]
      end

      def source_table = @association.arel_table
    end
  end
end

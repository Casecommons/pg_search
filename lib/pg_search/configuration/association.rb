# frozen_string_literal: true

require "digest"

module PgSearch
  class Configuration
    class Association
      attr_reader :columns

      def initialize(model, name, column_names)
        @model = model
        @name = name
        @columns = Array(column_names).map do |column_name, weight|
          ForeignColumn.new(column_name, weight, @model, self)
        end
      end

      def table_name
        @model.reflect_on_association(@name).table_name
      end

      def collection?
        @model.reflect_on_association(@name).collection?
      end

      def join(primary_key)
        "LEFT OUTER JOIN (#{relation(primary_key).to_sql}) #{subselect_alias} ON #{subselect_alias}.id = #{primary_key}"
      end

      def subselect_alias
        Configuration.alias(table_name, @name, "subselect")
      end

      private

      def selects
        if singular_association?
          selects_for_singular_association
        else
          selects_for_multiple_association
        end
      end

      def selects_for_singular_association
        postgresql_version = @model.connection.send(:postgresql_version)
        
        columns.map do |column|
          if collection?
            if column.tsvector_column
              "tsvector_agg(#{column.full_name}) AS #{column.alias}"
            else
              case postgresql_version
              when 0..90000
                "array_to_string(array_agg(#{column.full_name}::text), ' ') AS #{column.alias}"
              else
                "string_agg(#{column.full_name}::text, ' ') AS #{column.alias}"
              end
            end
          else
            "#{column.full_name} AS #{column.alias}"
          end
        end.join(", ")
      end

      def selects_for_multiple_association
        columns.map do |column|
          "string_agg(#{column.full_name}::text, ' ') AS #{column.alias}"
        end.join(", ")
      end

      def relation(primary_key)
        query = @model.unscoped.joins(@name).select("#{primary_key} AS id, #{selects}")
        query = query.group(primary_key) if collection?
        query
      end

      def singular_association?
        %i[has_one belongs_to].include?(@model.reflect_on_association(@name).macro)
      end
    end
  end
end

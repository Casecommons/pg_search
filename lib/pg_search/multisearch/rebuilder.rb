# frozen_string_literal: true

module PgSearch
  module Multisearch
    class Rebuilder
      # @param model [Class] an Active Record model configured for multisearch
      # @param time_source [#call] clock returning a timestamp for bulk inserts;
      #   defaults to Time.method(:now), called once per bulk rebuild so created_at
      #   and updated_at share a timestamp
      # @raise [ModelNotMultisearchable] if model is not configured for multisearch
      def initialize(model, time_source = Time.method(:now))
        raise ModelNotMultisearchable, model unless model.respond_to?(:pg_search_multisearchable_options)

        @model = model
        @time_source = time_source
      end

      # Populates search documents without first clearing existing documents.
      # Uses the model's rebuild_pg_search_documents override when available;
      # otherwise updates records individually for conditions, dynamic content,
      # or additional attributes, and bulk-inserts for plain column content.
      def rebuild
        if model.respond_to?(:rebuild_pg_search_documents)
          model.rebuild_pg_search_documents
        elsif conditional? || dynamic? || additional_attributes?
          model.find_each(&:update_pg_search_document)
        else
          model.connection.execute(rebuild_sql)
        end
      end

      private

      attr_reader :model

      def conditional?
        model.pg_search_multisearchable_options.key?(:if) ||
          model.pg_search_multisearchable_options.key?(:unless)
      end

      def dynamic?
        column_names = model.columns.map(&:name)
        columns.any? { |column| column_names.exclude?(column.to_s) }
      end

      def additional_attributes?
        model.pg_search_multisearchable_options.key?(:additional_attributes)
      end

      def connection = model.connection

      def rebuild_sql = connection.to_sql(insert_manager.ast)

      def insert_manager
        time = @time_source.call
        quoted_time = Arel::Nodes.build_quoted(time)
        src = model.arel_table
        doc = PgSearch::Document.arel_table

        sel = Arel::SelectManager.new(src)
        sel.project(
          Arel::Nodes.build_quoted(model.base_class.name).as("searchable_type"),
          src[model.primary_key].as("searchable_id"),
          content_expression.as("content"),
          quoted_time.as("created_at"),
          quoted_time.as("updated_at")
        )

        apply_sti_condition(sel, src)

        mgr = Arel::InsertManager.new
        mgr.into(doc)
        mgr.columns.concat([
          doc[:searchable_type],
          doc[:searchable_id],
          doc[:content],
          doc[:created_at],
          doc[:updated_at]
        ])
        mgr.select(sel.ast)
        mgr
      end

      def content_expression
        expressions = columns.map { |column| Configuration::Column.new(column, nil, model).to_arel }
        expressions.inject do |document, expression|
          Arel::Nodes::InfixOperation.new(
            "||",
            Arel::Nodes::InfixOperation.new("||", document, Arel::Nodes.build_quoted(" ")),
            expression
          )
        end
      end

      def columns = Array(model.pg_search_multisearchable_options[:against])

      def apply_sti_condition(select_manager, src_table)
        return unless model.column_names.include?(model.inheritance_column)

        inheritance_col = src_table[model.inheritance_column]
        type_match = inheritance_col.eq(model.name)

        condition = if model.base_class == model
          inheritance_col.eq(nil).or(type_match)
        else
          type_match
        end

        select_manager.where(condition)
      end
    end
  end
end

# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module PgSearch
  class ScopeOptions
    attr_reader :config, :feature_options, :model

    def initialize(config)
      @config = config
      @model = config.model
      @feature_options = config.feature_options
    end

    def apply(scope)
      scope = include_table_aliasing_for_rank(scope)
      rank_table_alias = scope.pg_search_rank_table_alias(include_counter: true)

      # Create proper Arel table reference for the subquery alias
      rank_table = Arel::Table.new(rank_table_alias)
      rank_column = rank_table[:rank]

      order_expression = [rank_column.desc]

      # Add order_within_rank - keep Arel.sql for user input, use proper Arel for our defaults
      if config.order_within_rank
        # User-provided ordering - must use Arel.sql to accept arbitrary SQL
        order_expression << Arel.sql(config.order_within_rank)
      else
        # Our default ordering - use proper Arel constructs
        primary_key_column = model.arel_table[model.primary_key]
        order_expression << primary_key_column.asc
      end

      scope_with_rank_join(scope, rank_table_alias)
        .order(order_expression)
        .extend(WithPgSearchRank)
        .extend(WithPgSearchHighlight[feature_for(:tsearch)])
    end

    module WithPgSearchHighlight
      def self.[](tsearch)
        Module.new do
          include WithPgSearchHighlight

          define_method(:tsearch) { tsearch }
        end
      end

      def tsearch
        raise TypeError, "You need to instantiate this module with []"
      end

      def with_pg_search_highlight
        scope = self
        scope = scope.select(arel_table[Arel.star]) unless scope.select_values.any?
        highlight_expression = highlight
        scope.select(highlight_expression.as("pg_search_highlight"))
      end

      def highlight
        tsearch.highlight
      end
    end

    module WithPgSearchRank
      def with_pg_search_rank
        scope = self
        scope = scope.select(arel_table[Arel.star]) unless scope.select_values.any?
        # Create proper Arel table reference for the subquery alias
        rank_table = Arel::Table.new(pg_search_rank_table_alias)
        rank_column = rank_table[:rank]
        scope.select(rank_column.as("pg_search_rank"))
      end
    end

    module PgSearchRankTableAliasing
      def pg_search_rank_table_alias(include_counter: false)
        components = [arel_table.name]
        if include_counter
          count = increment_counter
          components << count if count > 0
        end

        Configuration.alias(components)
      end

      private

      def increment_counter
        @counter ||= 0
      ensure
        @counter += 1
      end
    end

    private

    delegate :connection, :quoted_table_name, to: :model

    def subquery
      primary_key_column = model.arel_table[model.primary_key]
      # Handle both Arel nodes and SQL strings from rank()
      rank_result = rank
      rank_expression = rank_result.is_a?(String) ? Arel.sql(rank_result) : rank_result

      model
        .unscoped
        .select(primary_key_column.as("pg_search_id"))
        .select(rank_expression.as("rank"))
        .joins(subquery_join)
        .where(conditions)
        .limit(nil)
        .offset(nil)
    end

    def conditions
      expressions =
        config.features
          .reject { |_feature_name, feature_options| feature_options && feature_options[:sort_only] }
          .map { |feature_name, _feature_options| feature_for(feature_name).conditions }

      or_node(expressions)
    end

    # https://github.com/rails/rails/pull/51492
    # :nocov:
    # standard:disable Lint/DuplicateMethods
    or_arity = Arel::Nodes::Or.instance_method(:initialize).arity
    case or_arity
    when 1
      def or_node(expressions)
        Arel::Nodes::Or.new(expressions)
      end
    when 2
      def or_node(expressions)
        expressions.inject { |accumulator, expression| Arel::Nodes::Or.new(accumulator, expression) }
      end
    else
      raise "Unsupported arity #{or_arity} for Arel::Nodes::Or#initialize"
    end
    # :nocov:
    # standard:enable Lint/DuplicateMethods

    def order_within_rank
      config.order_within_rank || "#{primary_key_sql} ASC"
    end

    def primary_key
      model.arel_table[model.primary_key]
    end

    def primary_key_sql
      "#{quoted_table_name}.#{connection.quote_column_name(model.primary_key)}"
    end

    def subquery_join
      return nil unless config.associations.any?

      config.associations.map do |association|
        association.join(primary_key_sql)
      end
    end

    FEATURE_CLASSES = { # standard:disable Lint/UselessConstantScoping
      dmetaphone: Features::DMetaphone,
      tsearch: Features::TSearch,
      trigram: Features::Trigram
    }.freeze

    def feature_for(feature_name)
      feature_name = feature_name.to_sym
      feature_class = FEATURE_CLASSES[feature_name]

      raise ArgumentError, "Unknown feature: #{feature_name}" unless feature_class

      normalizer = Normalizer.new(config)

      feature_class.new(
        config.query,
        feature_options[feature_name],
        config.columns,
        config.model,
        normalizer
      )
    end

    def rank
      ranking_expression = config.ranking_sql || ":tsearch"

      # For simple single-feature expressions, return Arel node directly
      if ranking_expression.match(/\A:(\w+)\z/)
        feature_name = Regexp.last_match(1)
        return feature_for(feature_name).rank
      end

      # For complex expressions, use string substitution and Arel.sql
      ranking_expression.gsub(/:(\w*)/) do
        feature_for(Regexp.last_match(1)).rank.to_sql
      end
    end

    def scope_with_rank_join(scope, rank_table_alias)
      # Build join using pure Arel - no string interpolation whatsoever
      # Uses SelectManager to construct the join properly, then extracts the join source

      # Create a SelectManager to build the join structure
      builder = Arel::SelectManager.new

      # Build join components using Arel constructs
      rank_table = Arel::Table.new(rank_table_alias)
      primary_key_column = model.arel_table[model.primary_key]
      subquery_id_column = rank_table[:pg_search_id]
      join_condition = primary_key_column.eq(subquery_id_column)

      # Use SelectManager's native join methods to build the subquery join
      subquery_manager = subquery.arel
      builder.join(subquery_manager.as(rank_table_alias)).on(join_condition)

      # Extract the properly constructed join and apply it to the scope
      join_source = builder.join_sources.first
      scope.joins(join_source)
    end

    def include_table_aliasing_for_rank(scope)
      return scope if scope.included_modules.include?(PgSearchRankTableAliasing)

      scope.all.spawn.tap do |new_scope|
        new_scope.instance_eval { extend PgSearchRankTableAliasing }
      end
    end
  end
end

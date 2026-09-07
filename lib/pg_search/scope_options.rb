# frozen_string_literal: true

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
      rank_subquery = subquery.arel.as(rank_table_alias)

      scope
        .joins(rank_join(rank_subquery))
        .order(rank_subquery[:rank].desc)
        .order(order_within_rank)
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
        scope = scope.select(arel_table[Arel.star]) if scope.select_values.empty?
        scope.select(tsearch.highlight.as("pg_search_highlight"))
      end
    end

    module WithPgSearchRank
      def with_pg_search_rank
        scope = self
        scope = scope.select(arel_table[Arel.star]) if scope.select_values.empty?
        rank_table = arel_table.alias(pg_search_rank_table_alias)
        rank_column = Arel::Attributes::Attribute.new(rank_table, "rank")
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

    def subquery
      model
        .unscoped
        .select(model.arel_table[model.primary_key].as("pg_search_id"))
        .select(rank.as("rank"))
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

      Arel::Nodes::Or.new(expressions)
    end

    def order_within_rank
      if config.order_within_rank
        Arel.sql(config.order_within_rank)
      else
        model.arel_table[model.primary_key].asc
      end
    end

    def primary_key
      Arel::Attributes::Attribute.new(model.arel_table, model.primary_key)
    end

    def subquery_join
      config.associations.map { |association| association.to_arel(primary_key) }
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
      return feature_for(:tsearch).rank unless config.ranking_sql

      Arel.sql(config.ranking_sql.gsub(/:(\w*)/) do
        feature_for(Regexp.last_match(1)).rank.to_sql
      end)
    end

    def rank_join(rank_subquery)
      model.arel_table
        .join(rank_subquery)
        .on(model.arel_table[model.primary_key].eq(rank_subquery[:pg_search_id]))
        .join_sources
    end

    def include_table_aliasing_for_rank(scope)
      return scope if scope.include?(PgSearchRankTableAliasing)

      scope.all.spawn.tap do |new_scope|
        new_scope.instance_eval { extend PgSearchRankTableAliasing }
      end
    end
  end
end

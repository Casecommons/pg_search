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
        scope = scope.select("#{table_name}.*") unless scope.select_values.any?
        scope.select("(#{highlight}) AS pg_search_highlight")
      end

      def highlight
        tsearch.highlight.to_sql
      end
    end

    module WithPgSearchRank
      def with_pg_search_rank
        scope = self
        scope = scope.select("#{table_name}.*") unless scope.select_values.any?
        rank_column = Arel.sql("#{pg_search_rank_table_alias}.rank").as("pg_search_rank")
        scope.select(rank_column)
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
      model
        .unscoped
        .select(model.arel_table[model.primary_key].as("pg_search_id"))
        .select(Arel.sql(rank).as("rank"))
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
      "#{quoted_table_name}.#{connection.quote_column_name(model.primary_key)}"
    end

    def subquery_join
      if config.associations.any?
        config.associations.map do |association|
          association.join(primary_key)
        end.join(" ")
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
      (config.ranking_sql || ":tsearch").gsub(/:(\w*)/) do
        feature_for(Regexp.last_match(1)).rank.to_sql
      end
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

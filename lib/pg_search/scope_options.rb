# encoding: UTF-8

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
      unless scope.instance_variable_get(:@pg_search_scope_applied_count)
        scope = if ::ActiveRecord::VERSION::STRING < "4.0.0"
                  scope.scoped
                else
                  scope.all.spawn
                end
      end

      alias_id = scope.instance_variable_get(:@pg_search_scope_applied_count) || 0
      scope.instance_variable_set(:@pg_search_scope_applied_count, alias_id + 1)

      aka = pg_search_alias scope, alias_id

      scope
        .joins(rank_join(aka))
        .order("#{aka}.rank DESC, #{order_within_rank}")
        .extend(DisableEagerLoading)
        .extend(WithPgSearchRank)
    end

    # workaround for https://github.com/Casecommons/pg_search/issues/14
    module DisableEagerLoading
      def eager_loading?
        return false
      end
    end

    module WithPgSearchRank
      def with_pg_search_rank
        scope = self
        scope = scope.select("*") unless scope.select_values.any?
        arel_table = scope.instance_variable_get(:@table)
        aka = "pg_search_#{arel_table.name}"

        scope.select("#{aka}.rank AS pg_search_rank")
      end
    end

    private

    delegate :connection, :quoted_table_name, :to => :model

    def subquery
      model
        .unscoped
        .select("#{primary_key} AS pg_search_id")
        .select("#{rank} AS rank")
        .joins(subquery_join)
        .where(conditions)
        .limit(nil)
        .offset(nil)
    end

    def conditions
      config.features.reject do |feature_name, feature_options|
        feature_options && feature_options[:sort_only]
      end.map do |feature_name, feature_options|
        feature_for(feature_name).conditions
      end.inject do |accumulator, expression|
        Arel::Nodes::Or.new(accumulator, expression)
      end.to_sql
    end

    def order_within_rank
      config.order_within_rank || "#{primary_key} ASC"
    end

    def primary_key
      "#{quoted_table_name}.#{connection.quote_column_name(model.primary_key)}"
    end

    def subquery_join
      if config.associations.any?
        config.associations.map do |association|
          association.join(primary_key)
        end.join(' ')
      end
    end

    FEATURE_CLASSES = {
      :dmetaphone => Features::DMetaphone,
      :tsearch => Features::TSearch,
      :trigram => Features::Trigram
    }

    def feature_for(feature_name)
      feature_name = feature_name.to_sym
      feature_class = FEATURE_CLASSES[feature_name]

      raise ArgumentError.new("Unknown feature: #{feature_name}") unless feature_class

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
        feature_for($1).rank.to_sql
      end
    end

    def pg_search_alias(scope, n)
      arel_table = scope.instance_variable_get(:@table)
      prefix = "pg_search_#{arel_table.name}"

      0 == n ? prefix : "#{prefix}_#{n}"
    end

    def rank_join(aka)
      "INNER JOIN (#{subquery.to_sql}) #{aka} ON #{primary_key} = #{aka}.pg_search_id"
    end
  end
end

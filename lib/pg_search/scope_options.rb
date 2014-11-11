# encoding: UTF-8

require "active_support/core_ext/module/delegation"

module PgSearch
  class ScopeOptions
    attr_reader :config, :feature_options

    def initialize(config)
      @config = config
      @model = config.model
      @feature_options = config.feature_options
    end

    def apply(scope)
      scope.
        select("#{quoted_table_name}.*, (#{rank}) AS pg_search_rank").
        where(conditions).
        order("pg_search_rank DESC, #{order_within_rank}").
        joins(joins).
        extend(DisableEagerLoading)
    end

    # workaround for https://github.com/Casecommons/pg_search/issues/14
    module DisableEagerLoading
      def eager_loading?
        return false
      end
    end

    private

    delegate :connection, :quoted_table_name, :to => :@model

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
      "#{quoted_table_name}.#{connection.quote_column_name(@model.primary_key)}"
    end

    def joins
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
  end
end

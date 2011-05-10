require "active_support/core_ext/module/delegation"

module PgSearch
  class ScopeOptions
    attr_reader :model

    delegate :connection, :quoted_table_name, :sanitize_sql_array, :to => :model

    def initialize(name, model, config)
      @name = name
      @model = model
      @config = config

      @feature_options = @config.features.inject({}) do |features_hash, (feature_name, feature_options)|
        features_hash.merge(
          feature_name => feature_options
        )
      end
      @feature_names = @config.features.map { |feature_name, feature_options| feature_name }
    end

    def to_hash
      {
        :select => "#{quoted_table_name}.*, (#{rank}) AS pg_search_rank",
        :conditions => conditions,
        :order => "pg_search_rank DESC, #{primary_key} ASC",
        :joins => joins
      }
    end

    private

    def conditions
      @feature_names.map { |feature_name| "(#{sanitize_sql_array(feature_for(feature_name).conditions)})" }.join(" OR ")
    end

    def primary_key
      "#{quoted_table_name}.#{connection.quote_column_name(model.primary_key)}"
    end

    def joins
      @config.associations.map do |association|
        association.join(primary_key)
      end.join(' ')
    end

    def feature_for(feature_name)
      feature_name = feature_name.to_sym

      feature_class = {
        :dmetaphone => Features::DMetaphone,
        :tsearch => Features::TSearch,
        :trigram => Features::Trigram
      }[feature_name]

      raise ArgumentError.new("Unknown feature: #{feature_name}") unless feature_class

      normalizer = Normalizer.new(@config)

      feature_class.new(@config.query, @feature_options[feature_name], @config.columns, @model, normalizer)
    end

    def tsearch_rank
      sanitize_sql_array(@feature_names[Features::TSearch].rank)
    end

    def rank
      (@config.ranking_sql || ":tsearch").gsub(/:(\w*)/) do
        sanitize_sql_array(feature_for($1).rank)
      end
    end
  end
end

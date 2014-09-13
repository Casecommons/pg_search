require "active_record"
require "active_support/concern"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/string/strip"

require "pg_search/compatibility"
require "pg_search/configuration"
require "pg_search/extensions/arel"
require "pg_search/features"
require "pg_search/multisearch"
require "pg_search/multisearchable"
require "pg_search/normalizer"
require "pg_search/scope_options"
require "pg_search/version"

module PgSearch
  extend ActiveSupport::Concern
  include Compatibility::ActiveRecord3 if ActiveRecord::VERSION::MAJOR == 3

  mattr_accessor :multisearch_options
  self.multisearch_options = {}

  mattr_accessor :unaccent_function
  self.unaccent_function = "unaccent"

  module ClassMethods
    def pg_search_scope(name, options)
      options_proc = if options.respond_to?(:call)
                       options
                     else
                       unless options.respond_to?(:merge)
                         raise ArgumentError, "pg_search_scope expects a Hash or Proc"
                       end
                       lambda { |query| {:query => query}.merge(options) }
                     end

      _define_tsvector_rebuild_methods options

      method_proc = lambda do |*args|
        config = Configuration.new(options_proc.call(*args), self)
        scope_options = ScopeOptions.new(config)
        scope_options.apply(self)
      end

      if respond_to?(:define_singleton_method)
        define_singleton_method name, &method_proc
      else
        (class << self; self; end).send :define_method, name, &method_proc
      end
    end

    def multisearchable(options = {})
      include PgSearch::Multisearchable
      class_attribute :pg_search_multisearchable_options
      self.pg_search_multisearchable_options = options
    end

    def _define_tsvector_rebuild_methods(_options)
      if _options.is_a? Hash
        model = self
        config = Configuration.new(_options, model)
        if config.features.any? { |feature, feature_options| feature == :tsearch }
          scope_options = ScopeOptions.new(config)
          tsearch = scope_options.send :feature_for, :tsearch

          tsearch.instance_eval do
            column_name = options[:tsvector_column]
            return unless column_name

            search_columns = (columns || []).reject { |c| c.is_a?(PgSearch::Configuration::ForeignColumn) }
            terms = search_columns.map do |search_column|
              column_to_tsvector(search_column)
            end
            document = terms.join(" || ")

            quoted_column_name = connection.quote_column_name(column_name)
            rebuild_all_method_name = "rebuild_all_#{column_name.to_s.pluralize}".to_sym
            rebuild_all_proc = lambda do
              if search_columns.any?
                update_all "#{quoted_column_name} = #{document}"
              end
            end
            if model.respond_to?(:define_singleton_method)
              model.define_singleton_method rebuild_all_method_name, &rebuild_all_proc
            else
              (class << model; self; end).send :define_method, rebuild_all_method_name, &rebuild_all_proc
            end

            rebuild_single_method_name = "rebuild_#{column_name}".to_sym
            rebuild_single_proc = lambda do
              model.where(model.arel_table[model.primary_key].eq(id)).send(rebuild_all_method_name)
            end
            model.send :define_method, rebuild_single_method_name, &rebuild_single_proc

            columns_changed = lambda do |object|
              search_columns.any? { |column| object.send "#{column.name}_changed?" }
            end

            if options[:autorebuild]
              model.class_eval do
                after_save(rebuild_single_method_name, :if => columns_changed)
              end
            end
          end
        end
      end
    end
  end

  class << self
    def multisearch(*args)
      PgSearch::Document.search(*args)
    end

    def disable_multisearch
      Thread.current["PgSearch.enable_multisearch"] = false
      yield
    ensure
      Thread.current["PgSearch.enable_multisearch"] = true
    end

    def multisearch_enabled?
      if Thread.current.key?("PgSearch.enable_multisearch")
        Thread.current["PgSearch.enable_multisearch"]
      else
        true
      end
    end
  end

  class NotSupportedForPostgresqlVersion < StandardError; end
end

require "pg_search/document"
require "pg_search/railtie" if defined?(Rails)

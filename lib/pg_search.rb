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
require "pg_search/scope_builder"
require "pg_search/tsv_rebuild_methods"
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
      PgSearch::ScopeBuilder.new(self, name, options).define!
    end

    def multisearchable(options = {})
      include PgSearch::Multisearchable
      class_attribute :pg_search_multisearchable_options
      self.pg_search_multisearchable_options = options
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

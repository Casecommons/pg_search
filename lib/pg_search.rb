require "active_record"
require "active_support/concern"
require "active_support/core_ext/module/attribute_accessors"

module PgSearch
  autoload :Configuration, "pg_search/configuration"
  autoload :Document, "pg_search/document"
  autoload :Features, "pg_search/features"
  autoload :Multisearch, "pg_search/multisearch"
  autoload :Multisearchable, "pg_search/multisearchable"
  autoload :Normalizer, "pg_search/normalizer"
  autoload :Scope, "pg_search/scope"
  autoload :ScopeOptions, "pg_search/scope_options"
  autoload :Version, "pg_search/version"

  extend ActiveSupport::Concern

  mattr_accessor :multisearch_options
  self.multisearch_options = {}

  module ClassMethods
    def pg_search_scope(name, options)
      scope = PgSearch::Scope.new(name, self, options)
      define_singleton_method name, &scope.method(:build_relation)
    end

    def multisearchable(options = {})
      include PgSearch::Multisearchable
      class_attribute :pg_search_multisearchable_options
      self.pg_search_multisearchable_options = options
    end
  end

  def pg_search_rank
    read_attribute(:pg_search_rank).to_f
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
      Thread.current.key?("PgSearch.enable_multisearch") ? Thread.current["PgSearch.enable_multisearch"] : true
    end
  end

  class NotSupportedForPostgresqlVersion < StandardError; end
end

require "pg_search/railtie" if defined?(Rails)

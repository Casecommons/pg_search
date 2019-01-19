# frozen_string_literal: true

require "active_record"
require "active_support/concern"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/string/strip"

require "pg_search/configuration"
require "pg_search/features"
require "pg_search/multisearch"
require "pg_search/multisearchable"
require "pg_search/normalizer"
require "pg_search/scope_options"
require "pg_search/version"

module PgSearch
  extend ActiveSupport::Concern

  mattr_accessor :multisearch_options
  self.multisearch_options = {}

  mattr_accessor :unaccent_function
  self.unaccent_function = "unaccent"

  module ClassMethods
    def pg_search_scope(name, options)
      options_proc = if options.respond_to?(:call)
                       options
                     elsif options.respond_to?(:merge)
                       ->(query) { { :query => query }.merge(options) }
                     else
                       raise ArgumentError, 'pg_search_scope expects a Hash or Proc'
                     end

      define_singleton_method(name) do |*args|
        config = Configuration.new(options_proc.call(*args), self)
        scope_options = ScopeOptions.new(config)
        scope_options.apply(self)
      end
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

  def method_missing(symbol, *args)
    case symbol
    when :pg_search_rank
      raise PgSearchRankNotSelected unless respond_to?(:pg_search_rank)

      read_attribute(:pg_search_rank).to_f
    when :pg_search_highlight
      raise PgSearchHighlightNotSelected unless respond_to?(:pg_search_highlight)

      read_attribute(:pg_search_highlight)
    else
      super
    end
  end

  def respond_to_missing?(symbol, *args)
    case symbol
    when :pg_search_rank
      attributes.key?(:pg_search_rank)
    when :pg_search_highlight
      attributes.key?(:pg_search_highlight)
    else
      super
    end
  end

  class PgSearchRankNotSelected < StandardError
    def message
      "You must chain .with_pg_search_rank after the pg_search_scope " \
      "to access the pg_search_rank attribute on returned records"
    end
  end

  class PgSearchHighlightNotSelected < StandardError
    def message
      "You must chain .with_pg_search_highlight after the pg_search_scope " \
      "to access the pg_search_highlight attribute on returned records"
    end
  end
end

ActiveSupport.on_load(:active_record) do
  require "pg_search/document"
end

require "pg_search/railtie" if defined?(Rails)

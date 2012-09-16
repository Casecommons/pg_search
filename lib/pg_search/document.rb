require "logger"

module PgSearch
  class Document < ActiveRecord::Base
    include PgSearch
    self.table_name = 'pg_search_documents'
    belongs_to :searchable, :polymorphic => true

    before_validation :update_content

    # The logger might not have loaded yet.
    # https://github.com/Casecommons/pg_search/issues/26
    def self.logger
      super || Logger.new(STDERR)
    end

    pg_search_scope :search, lambda { |*args|
      options = if PgSearch.multisearch_options.respond_to?(:call)
        PgSearch.multisearch_options.call(*args)
      else
        {:query => args.first}.merge(PgSearch.multisearch_options)
      end

      {:against => :content}.merge(options)
    }

    private

    def update_content
      methods = Array(searchable.pg_search_multisearchable_options[:against])
      searchable_text = methods.map { |symbol| searchable.send(symbol) }.join(" ")
      self.content = searchable_text
    end
  end
end

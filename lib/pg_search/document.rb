require "pg_search/scope"

module PgSearch
  class Document < ActiveRecord::Base
    include PgSearch
    self.table_name = 'pg_search_documents'
    belongs_to :searchable, :polymorphic => true

    before_validation :update_content

    pg_search_scope :search, lambda { |*args|
      if PgSearch.multisearch_options.respond_to?(:call)
        options = PgSearch.multisearch_options.call(*args)
      else
        options = PgSearch.multisearch_options.reverse_merge(:query => args.first)
      end
      options.reverse_merge(:against => :content)
    }

    private

    def update_content
      methods = Array.wrap(searchable.pg_search_multisearchable_options[:against])
      searchable_text = methods.map { |symbol| searchable.send(symbol) }.join(" ")
      self.content = searchable_text
    end
  end
end

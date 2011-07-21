require "pg_search/scope"

module PgSearch
  class Document < ActiveRecord::Base
    include PgSearch
    set_table_name :pg_search_documents
    belongs_to :searchable, :polymorphic => true

    before_validation :update_content

    pg_search_scope :search, :against => :content

    private

    def update_content
      methods = Array.wrap(searchable.pg_search_multisearchable_options[:against])
      searchable_text = methods.map { |symbol| searchable.send(symbol) }.join(" ")
      self.content = searchable_text
    end
  end
end

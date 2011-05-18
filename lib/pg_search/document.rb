module PgSearch
  class Document < ActiveRecord::Base
    set_table_name :pg_search_documents
    belongs_to :searchable, :polymorphic => true
  end
end

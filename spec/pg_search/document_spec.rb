require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PgSearch::Document do
  with_table "pg_search_documents", {}, &DOCUMENTS_SCHEMA

  it { should be_an(ActiveRecord::Base) }
end

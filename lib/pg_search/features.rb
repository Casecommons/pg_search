# frozen_string_literal: true

require "pg_search/features/feature"

require "pg_search/features/dmetaphone"
require "pg_search/features/trigram"
require "pg_search/features/tsearch"

module PgSearch
  # Search features provide conditions and rank as composable Arel expressions,
  # not SQL Strings. TSearch also provides a highlight expression for selection.
  module Features
  end
end

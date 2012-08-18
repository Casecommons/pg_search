module PgSearch
  module Features
    autoload :Feature, "pg_search/features/feature"

    autoload :DMetaphone, "pg_search/features/dmetaphone"
    autoload :Trigram, "pg_search/features/trigram"
    autoload :TSearch, "pg_search/features/tsearch"
  end
end

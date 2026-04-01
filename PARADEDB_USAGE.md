# Using pg_search with ParadeDB

This document explains how to use the pg_search gem with ParadeDB's pg_search PostgreSQL extension for BM25-based full-text search.

## Prerequisites

1. Install the ParadeDB pg_search PostgreSQL extension in your database
2. Use pg_search gem version 2.3.7 or later with ParadeDB support

## Setup

### 1. Configure Multisearch to use ParadeDB

In your Rails initializer (e.g., `config/initializers/pg_search.rb`):

```ruby
PgSearch.multisearch_options = {
  using: :paradedb
}
```

### 2. Run the ParadeDB migration

Generate and run the migration to set up ParadeDB:

```bash
rails generate pg_search:migration:paradedb
rails db:migrate
```

This migration will:
- Install the pg_search PostgreSQL extension
- Create a BM25 index on the pg_search_documents table

### 3. Usage Examples

#### Basic Search

```ruby
# Perform a multisearch using ParadeDB's BM25 algorithm
results = PgSearch.multisearch("red shoes")

# Results are automatically ranked by BM25 score
results.each do |document|
  puts "#{document.searchable_type} ##{document.searchable_id}"
  puts "Content: #{document.content}"
end
```

#### Advanced Query Types

```ruby
# Configure ParadeDB with query options
PgSearch.multisearch_options = {
  using: {
    paradedb: {
      # Phrase search - finds exact phrases
      query_type: :phrase
    }
  }
}

# Search for an exact phrase
PgSearch.multisearch("red running shoes")

# Prefix search - finds words starting with prefix
PgSearch.multisearch_options = {
  using: {
    paradedb: {
      query_type: :prefix
    }
  }
}
PgSearch.multisearch("sho") # Finds: shoes, shopping, etc.

# Fuzzy search - finds similar words
PgSearch.multisearch_options = {
  using: {
    paradedb: {
      query_type: :fuzzy,
      fuzzy_distance: 2  # Allow up to 2 character differences
    }
  }
}
PgSearch.multisearch("sheos") # Finds: shoes
```

### 4. Model-specific Search

You can also use ParadeDB for model-specific searches:

```ruby
class Product < ApplicationRecord
  include PgSearch::Model
  
  pg_search_scope :search_products,
    against: [:name, :description],
    using: {
      paradedb: {
        key_field: 'id'  # Specify the primary key field
      }
    }
end

# Use it
products = Product.search_products("laptop")
```

### 5. Combining with Rankings

ParadeDB results are automatically ordered by BM25 score. You can access the rank:

```ruby
results = PgSearch.multisearch("shoes").with_pg_search_rank

results.each do |result|
  puts "Score: #{result.pg_search_rank}"
  puts "Result: #{result.searchable}"
end
```

## Migration Details

The ParadeDB migration creates a BM25 index with this structure:

```sql
CREATE INDEX pg_search_documents_bm25_idx 
ON pg_search_documents 
USING bm25 (searchable_id, searchable_type, content)
WITH (key_field='searchable_id');
```

The `key_field` parameter is crucial as it's used by ParadeDB's `score()` function for ranking.

## Performance Considerations

1. **BM25 vs TSearch**: ParadeDB's BM25 algorithm often provides better relevance ranking than PostgreSQL's built-in TSearch, especially for longer documents.

2. **Index Size**: BM25 indexes can be larger than TSearch indexes but provide faster query performance.

3. **Query Syntax**: ParadeDB supports a rich query syntax including wildcards, fuzzy matching, and phrase queries.

## Limitations

1. ParadeDB features are only available when the pg_search PostgreSQL extension is installed
2. Some advanced TSearch features (like language-specific stemming) may work differently with ParadeDB
3. The multisearch table must have a numeric key field for scoring to work properly

## Troubleshooting

If you encounter errors:

1. Ensure the pg_search PostgreSQL extension is installed:
   ```sql
   CREATE EXTENSION IF NOT EXISTS pg_search;
   ```

2. Verify the BM25 index exists:
   ```sql
   \di pg_search_documents_bm25_idx
   ```

3. Check that your queries are properly escaped (single quotes are automatically handled by the gem)

## Further Reading

- [ParadeDB Documentation](https://docs.paradedb.com/)
- [pg_search Extension on Neon](https://neon.tech/docs/extensions/pg_search)
- [BM25 Algorithm](https://en.wikipedia.org/wiki/Okapi_BM25)
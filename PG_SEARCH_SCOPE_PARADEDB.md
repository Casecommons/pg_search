# Using ParadeDB with pg_search_scope

This document explains how to use ParadeDB's BM25 search algorithm with pg_search_scope for model-specific searches.

## Basic Usage

### Simple Search

```ruby
class Product < ApplicationRecord
  include PgSearch::Model
  
  # Basic ParadeDB search on a single column
  pg_search_scope :search_by_name, 
    against: :name, 
    using: :paradedb
end

# Usage
Product.search_by_name("laptop")
```

### Multi-Column Search

```ruby
class Article < ApplicationRecord
  include PgSearch::Model
  
  # Search across multiple columns with BM25
  pg_search_scope :search_content,
    against: [:title, :body, :summary],
    using: :paradedb
end

# Usage
Article.search_content("ruby programming")
```

## Advanced Configuration

### ParadeDB-Specific Options

```ruby
class Document < ApplicationRecord
  include PgSearch::Model
  
  pg_search_scope :advanced_search,
    against: [:title, :content],
    using: {
      paradedb: {
        # Query types
        query_type: :phrase,      # :standard (default), :phrase, :prefix, :fuzzy
        fuzzy_distance: 2,        # For fuzzy search (edit distance)
        
        # Index management
        auto_create_index: true,  # Auto-create BM25 index (default: true)
        check_extension: true,    # Check pg_search extension (default: true)
        index_name: 'custom_idx', # Custom index name
        
        # Key field for scoring
        key_field: 'id'          # Primary key field (default: model's primary key)
      }
    }
end

# Different query types
Document.advanced_search("exact phrase")           # Phrase search
Document.advanced_search("pref")                   # With query_type: :prefix
Document.advanced_search("similr")                 # With query_type: :fuzzy
```

### Combining with Other Search Methods

```ruby
class Product < ApplicationRecord
  include PgSearch::Model
  
  # Combine ParadeDB with other search methods
  pg_search_scope :hybrid_search,
    against: [:name, :description],
    using: {
      paradedb: {},                    # BM25 ranking
      tsearch: { prefix: true },       # Full-text with prefix
      trigram: { threshold: 0.3 }      # Fuzzy matching
    }
end
```

### Weighted Columns

```ruby
class BlogPost < ApplicationRecord
  include PgSearch::Model
  
  # Weighted search (ParadeDB will consider weights in BM25 scoring)
  pg_search_scope :weighted_search,
    against: {
      title: 'A',      # Highest weight
      summary: 'B',    # Medium weight
      content: 'C'     # Lower weight
    },
    using: :paradedb
end
```

## Performance Optimization

### Disable Checks in Production

```ruby
class Product < ApplicationRecord
  include PgSearch::Model
  
  # Disable runtime checks for better performance
  pg_search_scope :fast_search,
    against: :name,
    using: {
      paradedb: {
        check_extension: false,    # Skip extension check
        auto_create_index: false   # Don't auto-create indexes
      }
    }
end
```

### Custom Index Names

```ruby
class LargeTable < ApplicationRecord
  include PgSearch::Model
  
  # Use shorter index names to avoid PostgreSQL's 63-char limit
  pg_search_scope :search_all,
    against: [:very_long_column_name_1, :very_long_column_name_2],
    using: {
      paradedb: {
        index_name: 'large_table_search_idx'
      }
    }
end
```

## Index Management

### Automatic Index Creation

When you define a pg_search_scope with ParadeDB, it automatically creates a BM25 index on first use:

```sql
-- Automatically created index
CREATE INDEX CONCURRENTLY products_name_bm25_idx 
ON products 
USING bm25 (id, name)
WITH (key_field='id');
```

### Manual Index Creation

You can also create indexes manually for better control:

```ruby
class CreateProductSearchIndex < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      CREATE INDEX products_search_idx
      ON products
      USING bm25 (id, name, description, category)
      WITH (key_field='id')
    SQL
  end
  
  def down
    execute "DROP INDEX IF EXISTS products_search_idx"
  end
end
```

Then reference it in your model:

```ruby
pg_search_scope :search,
  against: [:name, :description, :category],
  using: {
    paradedb: {
      index_name: 'products_search_idx',
      auto_create_index: false  # Don't create another index
    }
  }
```

## Ranking and Ordering

### Using ParadeDB Ranking

```ruby
class Product < ApplicationRecord
  include PgSearch::Model
  
  # ParadeDB automatically ranks by BM25 score
  pg_search_scope :ranked_search,
    against: [:name, :description],
    using: :paradedb
end

# Results are automatically ordered by relevance
products = Product.ranked_search("gaming laptop")

# Access the rank score
products_with_rank = Product.ranked_search("gaming laptop").with_pg_search_rank
products_with_rank.each do |product|
  puts "#{product.name}: #{product.pg_search_rank}"
end
```

### Custom Ranking

```ruby
class Article < ApplicationRecord
  include PgSearch::Model
  
  pg_search_scope :custom_ranked_search,
    against: [:title, :content],
    using: :paradedb,
    ranked_by: ":paradedb * 0.8 + :popularity * 0.2"
end
```

## Migration Generator

Generate a migration to set up ParadeDB:

```bash
rails generate pg_search:migration:paradedb
rails db:migrate
```

This creates:
1. The pg_search PostgreSQL extension
2. A BM25 index on pg_search_documents (for multisearch)

## Troubleshooting

### Extension Not Found

If you get an error about the pg_search extension:

```ruby
PgSearch::Features::ParadeDB::ExtensionNotInstalled: ParadeDB pg_search extension is not installed.
```

Run this SQL command:
```sql
CREATE EXTENSION IF NOT EXISTS pg_search;
```

### Index Creation Failed

If automatic index creation fails, create it manually:

```sql
CREATE INDEX your_table_columns_bm25_idx
ON your_table
USING bm25 (id, column1, column2)
WITH (key_field='id');
```

### Performance Issues

For large tables, disable automatic checks:

```ruby
pg_search_scope :search,
  against: :content,
  using: {
    paradedb: {
      check_extension: Rails.env.development?,
      auto_create_index: Rails.env.development?
    }
  }
```

## Differences from Other Search Methods

- **BM25 Algorithm**: ParadeDB uses BM25 ranking, often providing better relevance than TF-IDF
- **No Language Processing**: Unlike tsearch, ParadeDB doesn't do stemming or stop-word removal
- **Case Sensitive**: ParadeDB searches are case-sensitive by default
- **Exact Matching**: More precise than trigram's fuzzy matching
- **Performance**: Generally faster than trigram for large datasets
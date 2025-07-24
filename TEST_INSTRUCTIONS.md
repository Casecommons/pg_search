# Testing ParadeDB Integration

Follow these steps to test the ParadeDB integration:

## 1. Ensure the gem changes are available in the backend

Since the pg_search gem is symlinked, the changes should be available. If not, you may need to:
```bash
cd /Users/jak/projects/SimplerQMS/backend
bundle install
```

## 2. Connect to the backend container

```bash
docker compose exec api bash
```

## 3. Run the Rails console

```bash
rails console
```

## 4. Test basic multisearch

```ruby
# Test basic search
results = ::PgSearch.multisearch("policy")
puts "Found #{results.count} results"
results.first(5).each { |r| puts "#{r.searchable_type} ##{r.searchable_id}: #{r.content[0..100]}..." }
```

## 5. Test with ranking

```ruby
# Test search with ranking
ranked_results = ::PgSearch.multisearch("policy").with_pg_search_rank
puts "Found #{ranked_results.count} results with ranking"
ranked_results.first(5).each do |r| 
  puts "Score: #{r.pg_search_rank} - #{r.searchable_type} ##{r.searchable_id}"
end
```

## 6. Test different query types

```ruby
# Test phrase search
PgSearch.multisearch_options = { using: { paradedb: { query_type: :phrase } } }
phrase_results = ::PgSearch.multisearch("quality management")
puts "Phrase search found #{phrase_results.count} results"

# Test prefix search
PgSearch.multisearch_options = { using: { paradedb: { query_type: :prefix } } }
prefix_results = ::PgSearch.multisearch("pol")
puts "Prefix search found #{prefix_results.count} results"

# Reset to default
PgSearch.multisearch_options = { using: :paradedb }
```

## Expected Results

If the integration is working correctly:
1. Searches should return results without errors
2. The `with_pg_search_rank` method should provide ranking scores
3. Different query types should produce different results

## Troubleshooting

If you get errors:

1. Check if the ParadeDB extension is installed:
   ```sql
   SELECT * FROM pg_extension WHERE extname = 'pg_search';
   ```

2. Check if the BM25 index exists:
   ```sql
   \di pg_search_documents*
   ```

3. Enable SQL logging to see the generated queries:
   ```ruby
   ActiveRecord::Base.logger = Logger.new(STDOUT)
   ```

## Restoring Original Configuration

After testing, restore the original configuration:
```bash
# Edit /Users/jak/projects/SimplerQMS/backend/config/initializers/global_search.rb
# Restore the original multisearch options
```
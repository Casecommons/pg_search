# Setting up Local pg_search Gem in Backend

Since the backend container isn't recognizing the ParadeDB feature, you need to configure it to use your local pg_search gem. Here are the steps:

## Option 1: Using Bundle Config (Recommended for Docker)

1. First, exit the Rails console and the Docker container

2. In your host machine, navigate to the backend directory:
   ```bash
   cd /Users/jak/projects/SimplerQMS/backend
   ```

3. Configure bundler to use the local pg_search gem:
   ```bash
   bundle config set --local local.pg_search /Users/jak/projects/pg_search
   ```

4. Update the Gemfile to use the local path:
   ```ruby
   # In /Users/jak/projects/SimplerQMS/backend/Gemfile
   # Change this line:
   gem "pg_search"
   
   # To this:
   gem "pg_search", path: "/Users/jak/projects/pg_search"
   ```

5. Rebuild the Docker container with the new gem:
   ```bash
   docker compose down
   docker compose build api
   docker compose up -d
   ```

## Option 2: Using Docker Volume Mount

Add a volume mount to your docker-compose.yml to map the local pg_search gem:

```yaml
services:
  api:
    volumes:
      - ./backend:/usr/src/app
      - /Users/jak/projects/pg_search:/usr/local/bundle/gems/pg_search-2.3.7
```

## Option 3: Quick Test Without Rebuilding

For a quick test without rebuilding, you can manually copy the files into the running container:

1. Copy the new ParadeDB files into the container:
   ```bash
   docker cp /Users/jak/projects/pg_search/lib/pg_search/features/paradedb.rb simplerqms-api-1:/usr/local/bundle/gems/pg_search-2.3.7/lib/pg_search/features/
   docker cp /Users/jak/projects/pg_search/lib/pg_search/features.rb simplerqms-api-1:/usr/local/bundle/gems/pg_search-2.3.7/lib/pg_search/
   docker cp /Users/jak/projects/pg_search/lib/pg_search/scope_options.rb simplerqms-api-1:/usr/local/bundle/gems/pg_search-2.3.7/lib/pg_search/
   ```

2. Enter the container and restart Rails:
   ```bash
   docker compose exec api bash
   rails console
   ```

## Verification

After applying one of the above methods, verify the setup:

```ruby
# In Rails console
require 'pg_search/features/paradedb'
PgSearch::Features::ParadeDB # Should not raise an error

# Check if ParadeDB is in the feature list
PgSearch::ScopeOptions::FEATURE_CLASSES.keys
# Should include :paradedb

# Then test the search
::PgSearch.multisearch("policy")
```

## Alternative: Fallback to Standard Features

If you need to test immediately without the gem setup, you can temporarily revert the configuration:

```ruby
# In Rails console
PgSearch.multisearch_options = {
  using: [:tsearch, :trigram, :dmetaphone],
  ignoring: :accents,
  ranked_by: ":dmetaphone + (0.25 * :trigram)"
}

# This should work with the existing gem
::PgSearch.multisearch("policy")
```
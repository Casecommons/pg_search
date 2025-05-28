# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

**Testing:**
- `bin/rspec` - Run all tests
- `bin/rspec spec/path/to/specific_spec.rb` - Run specific test file
- `bin/rspec spec/path/to/specific_spec.rb:123` - Run specific test at line 123

**Code Quality:**
- `bin/rake standard` - Run StandardRB linter/formatter
- `bin/rake standard:fix` - Auto-fix linting issues
- `bin/rake undercover` - Check test coverage against changes
- `bin/rake` - Default task: runs spec, standard, and undercover

**Database Setup (for specs):**
- Database configuration is in `spec/support/database.rb`
- Tests use in-memory SQLite or PostgreSQL depending on setup
- Specs automatically handle database setup/teardown

**Migration Generation:**
- `rails g pg_search:migration:multisearch` - Generate multisearch table migration
- `rails g pg_search:migration:dmetaphone` - Generate dmetaphone support functions

## Architecture Overview

**Core Components:**
- `PgSearch::Model` - Main mixin providing `pg_search_scope` for model-specific search
- `PgSearch::Multisearchable` - Cross-model search using `pg_search_documents` table
- `PgSearch::Features` - Pluggable search algorithms (TSearch, Trigram, DMetaphone)
- `PgSearch::Configuration` - Validates and organizes search parameters
- `PgSearch::ScopeOptions` - Builds Active Record scopes with ranking from configurations

**Two Search Approaches:**
1. **Search Scopes** (`pg_search_scope`) - Search within a single model's data and associations
2. **Multisearch** (`multisearchable`) - Global search across different model types using indexed documents

**Feature System:**
- Each search feature inherits from `PgSearch::Features::Feature`
- Features implement `conditions()` for WHERE clauses and `rank()` for ORDER BY
- Multiple features can be combined using OR logic for conditions and weighted ranking
- Supported features: `:tsearch` (full-text), `:trigram` (fuzzy matching), `:dmetaphone` (phonetic)

**Configuration Flow:**
1. `pg_search_scope` creates `Configuration` object with validated options
2. `ScopeOptions` transforms configuration into ranked SQL subquery
3. Main scope JOINs with ranking subquery, adds search conditions
4. Optional modules add `.with_pg_search_rank` and `.with_pg_search_highlight` methods

**File Organization:**
- `lib/pg_search/features/` - Search algorithm implementations
- `lib/pg_search/configuration/` - Column and association handling
- `lib/pg_search/migration/` - Rails generator templates
- `spec/lib/pg_search/` - Unit tests mirroring lib structure
- `spec/integration/` - End-to-end feature tests

**Testing Patterns:**
- Uses `with_model` gem for creating temporary Active Record models in specs
- Database setup handled by `spec/support/database.rb`
- Integration specs test actual PostgreSQL search functionality
- Unit specs test individual components in isolation

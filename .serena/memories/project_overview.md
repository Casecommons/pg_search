# PgSearch Project Overview

## Purpose
PgSearch is a Ruby gem that builds named scopes that take advantage of PostgreSQL's full text search capabilities. It provides an easy way to add powerful search functionality to Active Record models using PostgreSQL's native features.

## Tech Stack
- **Language**: Ruby (3.2+)
- **Framework**: Active Record (7.1+)
- **Database**: PostgreSQL (9.2+)
- **Testing**: RSpec
- **Code Style**: Standard Ruby linter
- **Coverage**: SimpleCov with undercover

## Key Features
- Full text search using PostgreSQL's built-in capabilities
- Multi-search functionality across different models
- Support for tsearch, trigram, and dmetaphone search features
- Search ranking and highlighting
- Association-based searching

## Project Structure
- `lib/pg_search/` - Main library code
  - `features/` - Search feature implementations (tsearch, trigram, dmetaphone)
  - `configuration/` - Configuration and column handling
  - `multisearch/` - Multi-model search functionality
  - `migration/` - Rails migration generators
- `spec/` - RSpec test suite
- `sql/` - PostgreSQL SQL function definitions
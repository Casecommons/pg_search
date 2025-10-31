# Code Style and Conventions

## Ruby Style
- Uses Standard Ruby linter configuration
- Ruby version: 3.2+
- Frozen string literals enforced (`# frozen_string_literal: true`)
- Standard Performance and Standard Rails plugins enabled
- Target Rails version: 7.1

## Naming Conventions
- Snake_case for methods, variables, and file names
- CamelCase for class and module names
- Use descriptive method and variable names
- Private methods clearly separated with `private` keyword

## Code Organization
- Modules properly namespaced under `PgSearch`
- Feature classes in `PgSearch::Features`
- Configuration classes in `PgSearch::Configuration`
- Clear separation of concerns

## Documentation
- Use meaningful method names that are self-documenting
- Add comments for complex SQL generation logic
- Include examples in README for public API

## Testing Conventions
- Use RSpec for testing
- Integration tests in `spec/integration/`
- Unit tests organized by class structure
- Use `with_model` gem for dynamic model creation in tests
- Test coverage monitored with undercover gem
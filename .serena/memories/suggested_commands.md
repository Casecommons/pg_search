# Suggested Commands for PgSearch Development

## Testing
- `bundle exec rspec` - Run the full test suite
- `bundle exec rspec spec/path/to/specific_spec.rb` - Run specific test file

## Code Quality
- `bundle exec standardrb` - Run Standard Ruby linter
- `bundle exec standardrb --fix` - Auto-fix linting issues
- `bin/undercover --compare origin/master` - Check test coverage for changes

## Development Workflow
- `bundle install` - Install dependencies
- `bundle exec rake` - Run default tasks (spec + standard + undercover)
- `bundle exec rake spec` - Run tests only
- `bundle exec rake standard` - Run linter only

## Database Setup (for testing)
- The gem requires PostgreSQL with specific extensions
- Tests use `with_model` gem for creating test models dynamically

## Git Commands (macOS)
- `git status` - Check repository status
- `git add .` - Stage all changes
- `git commit -m "message"` - Commit changes
- `git push` - Push to remote repository

## File System Commands (macOS)
- `ls -la` - List files with details
- `find . -name "*.rb" | head -20` - Find Ruby files
- `grep -r "pattern" lib/` - Search for patterns in lib directory
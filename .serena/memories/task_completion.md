# Task Completion Checklist

## When a task is completed, run these commands in order:

### 1. Test the changes
```bash
bundle exec rspec
```
Ensure all existing tests pass.

### 2. Run the linter
```bash
bundle exec standardrb
```
Fix any style issues that are reported.

### 3. Check test coverage
```bash
bin/undercover --compare origin/master
```
Ensure test coverage is maintained for new/changed code.

### 4. Run the full default task
```bash
bundle exec rake
```
This runs spec + standard + undercover together.

## Additional Considerations
- If adding new public API methods, update the README with examples
- If changing SQL generation, test with various PostgreSQL versions if possible
- Consider performance implications of changes, especially in search queries
- Ensure changes maintain backward compatibility unless it's a breaking change release

## Git Workflow
After all checks pass:
```bash
git add .
git commit -m "Descriptive commit message"
git push
```
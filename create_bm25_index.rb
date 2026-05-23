# Create BM25 index for ParadeDB
# Run this in Rails console to set up the required index

puts "=" * 60
puts "Creating BM25 Index for ParadeDB"
puts "=" * 60

# First, check if pg_search extension is installed
puts "\n1. Checking pg_search extension..."
begin
  result = ActiveRecord::Base.connection.execute("SELECT * FROM pg_extension WHERE extname = 'pg_search'")
  if result.any?
    puts "✓ pg_search extension is installed"
  else
    puts "✗ pg_search extension is NOT installed"
    puts "  Installing pg_search extension..."
    ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS pg_search")
    puts "✓ pg_search extension installed"
  end
rescue => e
  puts "✗ Error with extension: #{e.message}"
end

# Create the BM25 index
puts "\n2. Creating BM25 index on pg_search_documents..."
begin
  # First, drop any existing BM25 index
  ActiveRecord::Base.connection.execute("DROP INDEX IF EXISTS pg_search_documents_bm25_idx")
  
  # Create the BM25 index
  # Note: We need to include all columns we want to search in the index
  create_index_sql = <<-SQL
    CREATE INDEX pg_search_documents_bm25_idx 
    ON pg_search_documents 
    USING bm25 (id, content, searchable_id, searchable_type)
    WITH (key_field='id')
  SQL
  
  ActiveRecord::Base.connection.execute(create_index_sql)
  puts "✓ BM25 index created successfully"
rescue => e
  puts "✗ Error creating index: #{e.message}"
  puts "  Trying alternative index configuration..."
  
  # Try a simpler index
  begin
    simpler_index_sql = <<-SQL
      CREATE INDEX pg_search_documents_bm25_idx 
      ON pg_search_documents 
      USING bm25 (content)
      WITH (key_field='id')
    SQL
    
    ActiveRecord::Base.connection.execute(simpler_index_sql)
    puts "✓ Simpler BM25 index created"
  rescue => e2
    puts "✗ Still failed: #{e2.message}"
  end
end

# Verify the index was created
puts "\n3. Verifying BM25 index..."
begin
  result = ActiveRecord::Base.connection.execute("SELECT indexname, indexdef FROM pg_indexes WHERE indexdef LIKE '%bm25%'")
  if result.any?
    puts "✓ BM25 indexes found:"
    result.each do |row|
      puts "  - #{row['indexname']}"
      puts "    #{row['indexdef']}"
    end
  else
    puts "✗ No BM25 indexes found after creation attempt"
  end
rescue => e
  puts "✗ Error checking indexes: #{e.message}"
end

# Test the search again
puts "\n4. Testing ParadeDB search with new index..."
begin
  sql = "SELECT * FROM pg_search_documents WHERE content @@@ 'policy' LIMIT 5"
  result = ActiveRecord::Base.connection.execute(sql)
  puts "✓ ParadeDB search works! Found #{result.count} results"
  
  if result.any?
    puts "\n  Sample results:"
    result.each_with_index do |row, i|
      puts "  #{i+1}. #{row['searchable_type']} ##{row['searchable_id']}"
      puts "     Content: #{row['content'][0..80]}..."
    end
  end
rescue => e
  puts "✗ Search still failing: #{e.message}"
end

# Test with score
puts "\n5. Testing ParadeDB with scoring..."
begin
  sql = "SELECT *, paradedb.score(id) as rank FROM pg_search_documents WHERE content @@@ 'policy' ORDER BY rank DESC LIMIT 5"
  result = ActiveRecord::Base.connection.execute(sql)
  puts "✓ ParadeDB search with scoring works!"
  
  result.each_with_index do |row, i|
    puts "  #{i+1}. Score: #{row['rank']} - #{row['searchable_type']} ##{row['searchable_id']}"
  end
rescue => e
  puts "✗ Scoring error: #{e.message}"
end

puts "\n" + "=" * 60
puts "Setup Complete"
puts "=" * 60
puts "\nNow try: ::PgSearch.multisearch('policy')"
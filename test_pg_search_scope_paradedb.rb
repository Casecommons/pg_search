# Test script for pg_search_scope with ParadeDB
# Run this in a Rails console to test ParadeDB integration with model-specific searches

puts "=" * 60
puts "Testing pg_search_scope with ParadeDB"
puts "=" * 60

# Test 1: Create a test model with ParadeDB search
puts "\n1. Creating test model with ParadeDB search..."
begin
  # Create a temporary table for testing
  ActiveRecord::Base.connection.execute(<<-SQL)
    CREATE TABLE IF NOT EXISTS test_products (
      id SERIAL PRIMARY KEY,
      name VARCHAR(255),
      description TEXT,
      category VARCHAR(100),
      created_at TIMESTAMP,
      updated_at TIMESTAMP
    )
  SQL
  
  # Define the model with ParadeDB search
  class TestProduct < ActiveRecord::Base
    self.table_name = 'test_products'
    include PgSearch::Model
    
    # Basic ParadeDB search
    pg_search_scope :search_by_name,
      against: :name,
      using: :paradedb
    
    # Multi-column ParadeDB search
    pg_search_scope :search_all,
      against: [:name, :description, :category],
      using: :paradedb
    
    # ParadeDB with options
    pg_search_scope :search_with_options,
      against: [:name, :description],
      using: {
        paradedb: {
          query_type: :prefix,
          auto_create_index: true
        }
      }
  end
  
  puts "✓ Test model created"
rescue => e
  puts "✗ Error creating model: #{e.message}"
end

# Test 2: Insert test data
puts "\n2. Inserting test data..."
begin
  TestProduct.delete_all
  
  TestProduct.create!([
    { name: "Gaming Laptop", description: "High-performance laptop for gaming", category: "Electronics" },
    { name: "Office Laptop", description: "Business laptop for office work", category: "Electronics" },
    { name: "Gaming Mouse", description: "RGB gaming mouse with high DPI", category: "Accessories" },
    { name: "Laptop Stand", description: "Ergonomic stand for laptops", category: "Accessories" },
    { name: "Gaming Keyboard", description: "Mechanical keyboard for gaming", category: "Accessories" }
  ])
  
  puts "✓ Created #{TestProduct.count} test products"
rescue => e
  puts "✗ Error inserting data: #{e.message}"
end

# Test 3: Test basic search
puts "\n3. Testing basic ParadeDB search..."
begin
  results = TestProduct.search_by_name("gaming")
  puts "✓ Found #{results.count} products matching 'gaming'"
  results.each { |p| puts "  - #{p.name}" }
rescue => e
  puts "✗ Error in basic search: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 4: Test multi-column search
puts "\n4. Testing multi-column search..."
begin
  results = TestProduct.search_all("laptop")
  puts "✓ Found #{results.count} products matching 'laptop' in any column"
  results.each { |p| puts "  - #{p.name}: #{p.description}" }
rescue => e
  puts "✗ Error in multi-column search: #{e.message}"
end

# Test 5: Test with ranking
puts "\n5. Testing search with BM25 ranking..."
begin
  results = TestProduct.search_all("gaming").with_pg_search_rank
  puts "✓ Search with ranking:"
  results.each do |p|
    puts "  - #{p.name} (Score: #{p.pg_search_rank})"
  end
rescue => e
  puts "✗ Error with ranking: #{e.message}"
end

# Test 6: Test prefix search
puts "\n6. Testing prefix search..."
begin
  results = TestProduct.search_with_options("gam")
  puts "✓ Found #{results.count} products with prefix 'gam'"
  results.each { |p| puts "  - #{p.name}" }
rescue => e
  puts "✗ Error in prefix search: #{e.message}"
end

# Test 7: Check created indexes
puts "\n7. Checking BM25 indexes..."
begin
  indexes = ActiveRecord::Base.connection.execute(<<-SQL)
    SELECT indexname, indexdef 
    FROM pg_indexes 
    WHERE tablename = 'test_products' 
    AND indexdef LIKE '%bm25%'
  SQL
  
  if indexes.any?
    puts "✓ Found BM25 indexes:"
    indexes.each do |idx|
      puts "  - #{idx['indexname']}"
    end
  else
    puts "✗ No BM25 indexes found"
  end
rescue => e
  puts "✗ Error checking indexes: #{e.message}"
end

# Test 8: Test combined search methods
puts "\n8. Testing combined search methods..."
begin
  class TestProduct < ActiveRecord::Base
    # Add a combined search scope
    pg_search_scope :hybrid_search,
      against: [:name, :description],
      using: {
        paradedb: {},
        tsearch: { prefix: true }
      }
  end
  
  results = TestProduct.hybrid_search("gaming")
  puts "✓ Hybrid search found #{results.count} results"
rescue => e
  puts "✗ Error in hybrid search: #{e.message}"
end

# Cleanup
puts "\n9. Cleanup..."
begin
  ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS test_products CASCADE")
  puts "✓ Test table dropped"
rescue => e
  puts "✗ Error during cleanup: #{e.message}"
end

puts "\n" + "=" * 60
puts "pg_search_scope ParadeDB Test Complete"
puts "=" * 60
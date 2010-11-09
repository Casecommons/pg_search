require "bundler/setup"
require "pg_search"

ActiveRecord::Base.establish_connection(:adapter  => 'postgresql',
                                        :database => 'pg_search_test')

begin
  ActiveRecord::Base.connection.execute("SELECT 1")
rescue PGError => e
  puts "-" * 80
  puts "Unable to connect to database.  Please run:"
  puts
  puts "    createdb pg_search_test"
  puts "-" * 80
  raise e
end

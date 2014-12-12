if defined? JRUBY_VERSION
  require 'activerecord-jdbcpostgresql-adapter'
  error_classes = [ActiveRecord::JDBCError]
else
  require "pg"
  error_classes = [PGError]
end

error_classes << ActiveRecord::NoDatabaseError if defined? ActiveRecord::NoDatabaseError

begin
  database_user = if ENV["TRAVIS"]
                    "postgres"
                  else
                    ENV["USER"]
                  end

  ActiveRecord::Base.establish_connection(:adapter  => 'postgresql',
                                          :database => 'pg_search_test',
                                          :username => database_user,
                                          :min_messages => 'warning')
  connection = ActiveRecord::Base.connection
  postgresql_version = connection.send(:postgresql_version)
  connection.execute("SELECT 1")
rescue *error_classes
  at_exit do
    puts "-" * 80
    puts "Unable to connect to database.  Please run:"
    puts
    puts "    createdb pg_search_test"
    puts "-" * 80
  end
  raise $!
end

if ENV["LOGGER"]
  require "logger"
  ActiveRecord::Base.logger = Logger.new(STDOUT)
end

def install_extension_if_missing(name, query, expected_result) # rubocop:disable Metrics/AbcSize
  connection = ActiveRecord::Base.connection
  postgresql_version = connection.send(:postgresql_version)
  result = connection.select_value(query)
  raise "Unexpected output for #{query}: #{result.inspect}" unless result.downcase == expected_result.downcase
rescue
  begin
    if postgresql_version >= 90100
      ActiveRecord::Base.connection.execute "CREATE EXTENSION #{name};"
    else
      share_path = `pg_config --sharedir`.strip
      ActiveRecord::Base.connection.execute File.read(File.join(share_path, 'contrib', "#{name}.sql"))
      puts $!.message
    end
  rescue => exception
    at_exit do
      puts "-" * 80
      puts "Please install the #{name} contrib module"
      puts "-" * 80
    end
    raise exception
  end
end

install_extension_if_missing("pg_trgm", "SELECT 'abcdef' % 'cdef'", "t")
unless postgresql_version < 90000
  install_extension_if_missing("unaccent", "SELECT unaccent('foo')", "foo")
end
install_extension_if_missing("fuzzystrmatch", "SELECT dmetaphone('foo')", "f")

def load_sql(filename)
  connection = ActiveRecord::Base.connection
  file_contents = File.read(File.join(File.dirname(__FILE__), '..', '..', 'sql', filename))
  connection.execute(file_contents)
end

if postgresql_version < 80400
  unless connection.select_value("SELECT 1 FROM pg_catalog.pg_aggregate WHERE aggfnoid = 'array_agg'::REGPROC") == "1"
    load_sql("array_agg.sql")
  end
  load_sql("unnest.sql")
end
load_sql("dmetaphone.sql")

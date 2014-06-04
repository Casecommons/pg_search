#### helper methods ####

def term_width_dashes(width=80)
 '-' * width
end

def install_extension_if_missing(name, query, expected_result)
  connection = ActiveRecord::Base.connection
  postgresql_version = connection.send(:postgresql_version)
  result = connection.select_value(query)
  raise "Unexpected output for #{query}: #{result.inspect}" unless result.downcase == expected_result.downcase
rescue => e
  begin
    if postgresql_version >= 90100
      ActiveRecord::Base.connection.execute "CREATE EXTENSION #{name};"
    else
      share_path = `pg_config --sharedir`.strip
      ActiveRecord::Base.connection.execute File.read(File.join(share_path, 'contrib', "#{name}.sql"))
      puts $!.message
    end
  rescue => e2
    at_exit do
      puts term_width_dashes
      puts "Please install the #{name} contrib module"
      puts term_width_dashes
    end

    raise e2
  end
end

def load_sql(filename)
  connection = ActiveRecord::Base.connection
  file_contents = File.read(File.join(File.dirname(__FILE__), '..', '..', 'sql', filename))
  connection.execute(file_contents)
end

def database_error_clasess
  error_classes = if defined? JRUBY_VERSION
    require 'activerecord-jdbcpostgresql-adapter'
    [ActiveRecord::JDBCError]
  else
    require 'pg'
    [PGError]
  end
  error_classes << ActiveRecord::NoDatabaseError if defined? ActiveRecord::NoDatabaseError
end

#### database connection setup ####

begin
  database_user = if ENV['TRAVIS']
                    'postgres'
                  else
                    ENV['USER']
                  end

  ActiveRecord::Base.establish_connection(:adapter  => 'postgresql',
                                          :database => 'pg_search_test',
                                          :username => database_user,
                                          :min_messages => 'warning')
  connection = ActiveRecord::Base.connection
  postgresql_version = connection.send(:postgresql_version)
  connection.execute('SELECT 1')
rescue *database_error_clasess
  at_exit do
    puts term_width_dashes
    puts 'Unable to connect to database.  Please run:'
    puts '    createdb pg_search_test'
    puts term_width_dashes
  end

  raise $!
end

#### install Postgres extensions ####

install_extension_if_missing('pg_trgm', "SELECT 'abcdef' % 'cdef'", 't')
install_extension_if_missing('unaccent', "SELECT unaccent('foo')", 'foo') unless postgresql_version < 90000
install_extension_if_missing('fuzzystrmatch', "SELECT dmetaphone('foo')", 'f')

#### load SQL ####

if postgresql_version < 80400
  load_sql('array_agg.sql') unless
    connection.select_value("SELECT 1 FROM pg_catalog.pg_aggregate WHERE aggfnoid = 'array_agg'::REGPROC") == '1'

  load_sql('unnest.sql')
end
load_sql('dmetaphone.sql')

require "bundler/setup"
require "pg_search"

begin
  ActiveRecord::Base.establish_connection(:adapter  => 'postgresql',
                                          :database => 'pg_search_test',
                                          :username => ('postgres' if ENV["TRAVIS"]),
                                          :min_messages => 'warning')
  connection = ActiveRecord::Base.connection
  postgresql_version = connection.send(:postgresql_version)
  connection.execute("SELECT 1")
  puts "postgresql_version = #{postgresql_version}"
rescue PGError => e
  puts "-" * 80
  puts "Unable to connect to database.  Please run:"
  puts
  puts "    createdb pg_search_test"
  puts "-" * 80
  raise e
end

if ENV["LOGGER"]
  require "logger"
  ActiveRecord::Base.logger = Logger.new(STDOUT)
end

def install_extension_if_missing(name, query, expected_result)
  connection = ActiveRecord::Base.connection
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
    puts "-" * 80
    puts "Please install the #{name} contrib module"
    puts "-" * 80
    raise e2
  end
end

install_extension_if_missing("pg_trgm", "SELECT 'abcdef' % 'cdef'", "t")
unless postgresql_version < 90000
  install_extension_if_missing("unaccent", "SELECT unaccent('foo')", "foo")
end
install_extension_if_missing("fuzzystrmatch", "SELECT dmetaphone('foo')", "f")

if postgresql_version < 80400
  unless connection.select_value("SELECT 1 FROM pg_catalog.pg_aggregate WHERE aggfnoid = 'array_agg'::REGPROC") == "1"
    connection.execute(File.read(File.join(File.dirname(__FILE__), '..', 'sql', 'array_agg.sql')))
  end
  connection.execute(File.read(File.join(File.dirname(__FILE__), '..', 'sql', 'unnest.sql')))
end
connection.execute(File.read(File.join(File.dirname(__FILE__), '..', 'sql', 'dmetaphone.sql')))

require "with_model"

RSpec.configure do |config|
  config.extend WithModel
end

RSpec::Matchers::OperatorMatcher.register(ActiveRecord::Relation, '=~', RSpec::Matchers::MatchArray)

DOCUMENTS_SCHEMA = lambda do |t|
  t.belongs_to :searchable, :polymorphic => true
  t.text :content
end

require 'irb'

class IRB::Irb
  alias initialize_orig initialize
  def initialize(workspace = nil, *args)
    default = IRB.conf[:DEFAULT_OBJECT]
    workspace ||= IRB::WorkSpace.new default if default
    initialize_orig(workspace, *args)
  end
end

# Drop into an IRB session for whatever object you pass in:
#
#     class Dude
#       def abides
#         true
#       end
#     end
#
#     console_for(Dude.new)
#
# Then type "quit" or "exit" to get out. In a step definition, it should look like:
#
#     When /^I console/ do
#       console_for(self)
#     end
#
# Also, I definitely stole this hack from some mailing list post somewhere. I wish I
# could remember who did it, but I can't. Sorry!
def console_for(target)
  puts "== ENTERING CONSOLE MODE. ==\nType 'exit' to move on.\nContext: #{target.inspect}"

  begin
    oldargs = ARGV.dup
    ARGV.clear
    IRB.conf[:DEFAULT_OBJECT] = target
    IRB.start
  ensure
    ARGV.replace(oldargs)
  end
end

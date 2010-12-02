require "bundler/setup"
require "pg_search"

begin
  ActiveRecord::Base.establish_connection(:adapter  => 'postgresql',
                                          :database => 'pg_search_test',
                                          :min_messages => 'warning')
  connection = ActiveRecord::Base.connection
  connection.execute("SELECT 1")
rescue PGError => e
  puts "-" * 80
  puts "Unable to connect to database.  Please run:"
  puts
  puts "    createdb pg_search_test"
  puts "-" * 80
  raise e
end

def install_contrib_module_if_missing(name, query, expected_result)
  connection = ActiveRecord::Base.connection
  result = connection.select_value(query)
  raise "Unexpected output for #{query}: #{result.inspect}" unless result.downcase == expected_result.downcase
rescue => e
  begin
    share_path = `pg_config --sharedir`.strip
    ActiveRecord::Base.connection.execute File.read(File.join(share_path, 'contrib', "#{name}.sql"))
    puts $!.message
  rescue
    puts "-" * 80
    puts "Please install the #{name} contrib module"
    puts "-" * 80
    raise e
  end
end

install_contrib_module_if_missing("pg_trgm", "SELECT 'abcdef' % 'cdef'", "t")
install_contrib_module_if_missing("unaccent", "SELECT unaccent('foo')", "foo")
install_contrib_module_if_missing("fuzzystrmatch", "SELECT dmetaphone('foo')", "f")

ActiveRecord::Base.connection.execute(File.read(File.join(File.dirname(__FILE__), '..', 'sql', 'dmetaphone.sql')))

require "with_model"

RSpec.configure do |config|
  config.extend WithModel
end

if defined?(ActiveRecord::Relation)
  RSpec::Matchers::OperatorMatcher.register(ActiveRecord::Relation, '=~', RSpec::Matchers::MatchArray)
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

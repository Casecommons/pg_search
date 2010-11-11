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

begin
  query = "SELECT 'abcdef' % 'cdef'"
  result = connection.select_value(query)
  raise "Unexpected output for #{query}: #{result.inspect}" unless result.downcase == "t"
rescue ActiveRecord::StatementInvalid => e
  begin
    share_path = `pg_config --sharedir`.strip
    ActiveRecord::Base.connection.execute File.read(File.join(share_path, 'contrib', 'pg_trgm.sql'))
  rescue
    puts "-" * 80
    puts "% operator is not present, please install the pg_trgm contrib module"
    puts "-" * 80
    raise e
  end
end


module WithModel
  class Dsl
    attr_reader :model_initialization

    def initialize(name, example_group)
      dsl = self

      @example_group = example_group
      @table_name = table_name = "with_model_#{name}_#{$$}"
      @model_initialization = lambda {}

      example_group.class_eval do
        attr_accessor name
      end

      example_group.before do
        send("#{name}=", Class.new(ActiveRecord::Base) do
          set_table_name table_name
          self.instance_eval(&dsl.model_initialization)
        end)
      end
    end

    def table(&block)
      @example_group.with_table(@table_name, &block)
    end

    def model(&block)
      @model_initialization = block
    end
  end

  def with_model(name, &block)
    Dsl.new(name, self).instance_eval(&block)
  end

  def with_table(name, &block)
    connection = ActiveRecord::Base.connection
    before do
      connection.drop_table(name) rescue nil
      connection.create_table(name, &block)
    end

    after do
      connection.drop_table(name) rescue nil
    end
  end
end

RSpec::Core::ExampleGroup.extend WithModel

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

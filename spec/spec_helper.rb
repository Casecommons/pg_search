require "bundler/setup"
require "pg_search"

ActiveRecord::Base.establish_connection(:adapter  => 'postgresql',
                                        :database => 'pg_search_test')

connection = ActiveRecord::Base.connection

begin
  connection.execute("SELECT 1")
rescue PGError => e
  puts "-" * 80
  puts "Unable to connect to database.  Please run:"
  puts
  puts "    createdb pg_search_test"
  puts "-" * 80
  raise e
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

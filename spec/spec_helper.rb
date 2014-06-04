require 'bundler/setup'
require 'pg_search'
require 'with_model'
require 'support/database'
#Dir['support/*.rb'].each {|f| require f}

if ENV['LOGGER']
  require 'logger'
  ActiveRecord::Base.logger = Logger.new(STDOUT)
end

RSpec.configure do |config|
  config.extend WithModel

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

DOCUMENTS_SCHEMA = lambda do |t|
  t.belongs_to :searchable, :polymorphic => true
  t.text :content
  t.timestamps
end

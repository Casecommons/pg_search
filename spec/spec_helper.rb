# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require "bundler/setup"
require "pg_search"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |c|
    c.syntax = :expect
  end

  config.example_status_persistence_file_path = 'tmp/examples.txt'
end

require 'support/database'
require 'support/with_model'

DOCUMENTS_SCHEMA = lambda do |t|
  t.belongs_to :searchable, :polymorphic => true, :index => true
  t.text :content
  t.timestamps null: false
end

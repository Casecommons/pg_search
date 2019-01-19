# frozen_string_literal: true

require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"
RuboCop::RakeTask.new do |t|
  t.options = %w[--display-cop-names]
end

task :codeclimate do
  sh 'bin/codeclimate-test-reporter' if ENV['CODECLIMATE_REPO_TOKEN']
end

task :default => %w[spec codeclimate rubocop]

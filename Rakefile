# frozen_string_literal: true

require "bundler"
Bundler::GemHelper.install_tasks

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

require "reek/rake/task"
Reek::Rake::Task.new do |t|
  t.fail_on_error = false
end

task default: %w[spec standard reek]

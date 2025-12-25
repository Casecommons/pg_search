# frozen_string_literal: true

require "bundler"
Bundler::GemHelper.install_tasks

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

task default: %w[spec standard]

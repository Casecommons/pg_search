# frozen_string_literal: true

require "bundler"
Bundler::GemHelper.install_tasks

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

desc "Check test coverage"
task :undercover do
  exit(1) unless system("bin/undercover --compare origin/master")
end

task default: %w[spec standard]
task default: %w[undercover] unless ENV["CI"]

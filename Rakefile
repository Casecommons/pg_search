require 'bundler'
Bundler::GemHelper.install_tasks

environments = %w[rails2 rails3]

in_environment = lambda do |environment, command|
  sh %Q{export BUNDLE_GEMFILE="gemfiles/#{environment}/Gemfile"; bundle --quiet && bundle exec #{command}}
end

in_all_environments = lambda do |command|
  environments.each do |environment|
    puts "\n---#{environment}---\n"
    in_environment.call(environment, command)
  end
end

desc "Run all specs against ActiveRecord 2 and 3"
task "spec" do
  in_all_environments.call('rspec spec')
end

namespace "autotest" do
  environments.each do |environment|
    desc "Run autotest in #{environment}"
    task environment do
      in_environment.call(environment, 'autotest -s rspec2')
    end
  end
end

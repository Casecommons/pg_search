require 'bundler'
Bundler::GemHelper.install_tasks

task :default => :spec

def bundle_exec(command)
  sh %Q{bundle update && bundle exec #{command}}
end

desc "Run all specs"
task "spec" do
  bundle_exec("rspec spec")
end

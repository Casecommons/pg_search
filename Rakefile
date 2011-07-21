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

task "doc" do
  bundle_exec("rspec --format d spec")
end

desc "Launch autotest"
task "autotest" do
  bundle_exec("autotest -s rspec2")
end

namespace "doc" do
  desc "Generate README and preview in browser"
  task "readme" do
    sh "rdoc -c utf8 README.rdoc && open doc/README_rdoc.html"
  end
end

# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = true
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Check YARD documentation coverage (must be 100%)"
task :yard do
  require "yard"

  # Capture the stats output
  stats = YARD::CLI::Stats.new
  stats.run("--list-undoc")

  # Check if there are any undocumented objects
  undocumented = stats.instance_variable_get(:@undoc_list) || []

  unless undocumented.empty?
    abort "\nYARD documentation check failed: #{undocumented.size} undocumented objects found."
  end

  puts "\nYARD documentation: 100% documented"
end

task default: %i[test rubocop yard]

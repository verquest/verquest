# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

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

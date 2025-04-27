# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc 'Run example script'
task :example do
  ruby 'examples/covered_call.rb'
end

desc 'Run benchmarks'
task :benchmark do
  ruby 'spec/benchmarks/benchmark.rb'
end

desc 'Generate documentation using YARD'
task :doc do
  sh 'mkdir -p docs/images'
  sh 'yard doc lib/**/*.rb --output-dir docs'
end

desc 'Clean temporary files and build artifacts'
task :clean do
  sh 'rm -rf *.gem *.rbc coverage .rspec docs doc'
  sh 'rm -rf .bundle vendor Gemfile.lock'
  sh 'rm -rf .yardoc log pkg tmp'
end

desc 'Open a console with the gem loaded'
task :console do
  require 'irb'
  require 'irb/completion'
  require 'option_lab'
  ARGV.clear
  IRB.start
end

# frozen_string_literal: true

require_relative "lib/option_lab/version"

Gem::Specification.new do |spec|
  spec.name = "option_lab"
  spec.version = OptionLab::VERSION
  spec.authors = ["Your Name"]
  spec.email = ["your.email@example.com"]

  spec.summary = "Ruby library for evaluating options trading strategies"
  spec.description = "A lightweight Ruby library designed to provide quick evaluation of option strategies."
  spec.homepage = "https://github.com/yourusername/option_lab"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "numo-narray", "~> 0.9.2"  # For numerical operations (similar to numpy)
  spec.add_dependency "numo-linalg", "~> 0.1.7"  # Linear algebra functions
  spec.add_dependency "distribution", "~> 0.8.0" # Statistical distributions
  spec.add_dependency "gnuplot", "~> 2.6.2"      # For plotting (similar to matplotlib)
  
  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
end

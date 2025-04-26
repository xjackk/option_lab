# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in option_lab.gemspec
gemspec

# Runtime dependencies - these are always installed
gem "numo-narray", "~> 0.9.2"
gem "numo-linalg", "~> 0.1.7"
gem "distribution", "~> 0.8.0"
gem "gnuplot", "~> 2.6.2"
gem "holidays", "~> 8.6.0"
gem "prime"
gem "bigdecimal"
gem "matrix"

# Development dependencies - only installed with `bundle install --with development`
group :development do
  gem "rake", "~> 13.0"
  gem "rspec", "~> 3.12"
  gem "rubocop-shopify", require: false
  gem "solargraph", "~> 0.49.0"
  gem "yard", "~> 0.9.34"
end

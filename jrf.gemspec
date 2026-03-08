# frozen_string_literal: true

require_relative "lib/jrf/version"

Gem::Specification.new do |spec|
  spec.name = "jrf"
  spec.version = Jrf::VERSION
  spec.authors = ["kazuho"]
  spec.email = ["n/a@example.com"]

  spec.summary = "JSON filter with the power and speed of Ruby"
  spec.description = "A JSON filter for NDJSON that uses Ruby expressions for transforms, selection, and aggregation."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.bindir = "exe"
  spec.executables = ["jrf"]

  spec.files = Dir.glob("{exe,lib,test}/*") + Dir.glob("lib/**/*") + %w[DESIGN.txt jrf.gemspec Gemfile Rakefile]
end

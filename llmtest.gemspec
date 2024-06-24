# frozen_string_literal: true

require_relative "lib/llmtest/version"

Gem::Specification.new do |spec|
  spec.name = "llmtest"
  spec.version = Llmtest::VERSION
  spec.authors = ["Laurin Kerkloh"]
  spec.email = ["laurin@kerk-loh.de"]

  spec.summary = "Write a short summary, because RubyGems requires one."
  spec.homepage = "https://github.com/LaurinKerkloh/llmtest"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["allowed_push_host"] = "Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  # Specify which files should be added to the gem 'hen it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir["lib/**/*.rb"] + Dir["bin/*"]
  spec.files += Dir["[A-Z]*"]
  spec.files.reject! { |fn| fn.include? "CVS" }

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a ne' dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  spec.add_dependency "rails"
  spec.add_dependency "ruby-openai", "~> 7.1.0"
  spec.add_dependency "parser"
  spec.add_dependency "simplecov"
  spec.add_dependency "ffast"

  spec.add_development_dependency "standard", "~> 1.36.0"
  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

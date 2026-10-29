# frozen_string_literal: true

require_relative "lib/quolle/version"

Gem::Specification.new do |spec|
  spec.name = "quolle"
  spec.version = Quolle::VERSION
  spec.authors = ["Quolle"]
  spec.summary = "Official Ruby SDK for the Quolle email API"
  spec.description = "Send transactional email through Quolle from Ruby."
  spec.homepage = "https://quolle.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata = {
    "homepage_uri" => "https://quolle.com",
    "documentation_uri" => "https://docs.quolle.com",
    "source_code_uri" => "https://github.com/Quolle-main/quolle-ruby"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end

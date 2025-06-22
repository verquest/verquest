# frozen_string_literal: true

require_relative "lib/verquest/gem_version"

Gem::Specification.new do |spec|
  spec.name = "verquest"
  spec.version = Verquest::GEM_VERSION
  spec.authors = ["Petr Hlavicka"]
  spec.email = ["yes@petr.codes"]

  spec.summary = "Verquest is a Ruby gem that offers an elegant solution for versioning API requests"
  spec.description = "Verquest helps you version API requests, simplifying the management of changes, handling the mapping for internal versus external names and structures, validating parameters, and exporting your requests to JSON Schema components for OpenAPI."
  spec.homepage = "https://github.com/CiTroNaK/verquest"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "zeitwerk", "~> 2.7"
  spec.add_dependency "json-schema", "~> 5.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

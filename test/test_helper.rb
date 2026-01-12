# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
    enable_coverage :branch

    add_group "Core", %w[lib/verquest.rb lib/verquest/base.rb]
    add_group "Properties", "lib/verquest/properties"
    add_group "Support", %w[
      lib/verquest/configuration.rb lib/verquest/result.rb lib/verquest/transformer.rb
      lib/verquest/version.rb lib/verquest/version_resolver.rb lib/verquest/versions.rb
    ]
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "verquest"

require "minitest/autorun"
require "mocha/minitest"

require_relative "support/configuration_test_helper"

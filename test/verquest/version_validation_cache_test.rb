# frozen_string_literal: true

require "test_helper"

module Verquest
  # Tests that a version compiles its validation schema once per configuration
  class VersionValidationCacheTest < Minitest::Test
    include ConfigurationTestHelper

    def test_compiles_the_schema_once_per_configuration
      request = Class.new(Verquest::Base) do
        version("2025-06") { field :name, type: :string, required: true }
      end
      version = request.send(:resolve, "2025-06")
      schemer = JSONSchemer.schema(version.validation_schema)
      uri = Verquest.configuration.json_schema_uri
      defaults = Verquest.configuration.insert_property_defaults
      [defaults, !defaults].each do |insert_property_defaults|
        JSONSchemer.expects(:schema).with(version.validation_schema, meta_schema: uri, insert_property_defaults:).once.returns(schemer)
      end

      3.times { version.validate_params(params: {}) }
      with_configuration(insert_property_defaults: !defaults) { 2.times { version.validate_params(params: {}) } }
    end

    def test_returns_errors_with_the_cached_schema
      request = Class.new(Verquest::Base) do
        version("2025-06") { field :name, type: :string, required: true }
      end
      version = request.send(:resolve, "2025-06")

      results = [{}, {"name" => "a"}, {}].map { |params| version.validate_params(params:).map { |error| error[:type] } }

      assert_equal [["required"], [], ["required"]], results
    end
  end
end

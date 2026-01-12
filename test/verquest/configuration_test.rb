# frozen_string_literal: true

require "test_helper"

module Verquest
  class ConfigurationTest < Minitest::Test
    include ConfigurationTestHelper

    def test_default_values
      config = Configuration.new

      expected = {
        validate_params: true,
        json_schema_version: :draft2020_12,
        validation_error_handling: :raise,
        remove_extra_root_keys: true,
        insert_property_defaults: true,
        default_additional_properties: false,
        custom_field_types: {},
        version_resolver: VersionResolver,
        current_version: nil
      }

      actual = {
        validate_params: config.validate_params,
        json_schema_version: config.json_schema_version,
        validation_error_handling: config.validation_error_handling,
        remove_extra_root_keys: config.remove_extra_root_keys,
        insert_property_defaults: config.insert_property_defaults,
        default_additional_properties: config.default_additional_properties,
        custom_field_types: config.custom_field_types,
        version_resolver: config.version_resolver,
        current_version: config.current_version
      }

      assert_equal expected, actual
    end

    def test_current_version_with_valid_callable
      config = Configuration.new
      callable = -> { "2025-06" }

      config.current_version = callable

      assert_equal callable, config.current_version
    end

    def test_current_version_with_invalid_value
      config = Configuration.new

      error = assert_raises(ArgumentError) do
        config.current_version = "not_callable"
      end

      assert_equal "The current_version must respond to a call method", error.message
    end

    def test_version_resolver_with_valid_callable
      config = Configuration.new
      custom_resolver = ->(version, versions) { versions.first }

      config.version_resolver = custom_resolver

      assert_equal custom_resolver, config.version_resolver
    end

    def test_version_resolver_with_invalid_value
      config = Configuration.new

      error = assert_raises(ArgumentError) do
        config.version_resolver = "not_callable"
      end

      assert_equal "The version_resolver must respond to a call method", error.message
    end

    def test_custom_field_types_with_valid_hash
      config = Configuration.new
      custom_types = {
        email: {type: "string", schema_options: {format: "email"}},
        uuid: {type: "string", schema_options: {format: "uuid"}}
      }

      config.custom_field_types = custom_types

      assert_equal "string", config.custom_field_types[:email][:type]
      assert_equal :format, config.custom_field_types[:email][:schema_options].keys.first
    end

    def test_custom_field_types_with_invalid_value
      config = Configuration.new

      error = assert_raises(ArgumentError) do
        config.custom_field_types = "not_a_hash"
      end

      assert_equal "Custom field types must be a Hash", error.message
    end

    def test_custom_field_types_ignores_default_types
      config = Configuration.new
      custom_types = {
        string: {type: "custom_string"}, # Should be ignored
        email: {type: "string"}
      }

      config.custom_field_types = custom_types

      refute config.custom_field_types.key?(:string)
      assert config.custom_field_types.key?(:email)
    end

    def test_json_schema_returns_correct_class
      config = Configuration.new

      config.json_schema_version = :draft7

      assert_equal JSONSchemer::Draft7, config.json_schema

      config.json_schema_version = :draft2020_12

      assert_equal JSONSchemer::Draft202012, config.json_schema
    end

    def test_json_schema_with_invalid_version
      config = Configuration.new
      config.json_schema_version = :invalid_version

      error = assert_raises(ArgumentError) do
        config.json_schema
      end

      assert_match(/Unsupported JSON Schema version/, error.message)
    end

    def test_json_schema_uri
      config = Configuration.new
      config.json_schema_version = :draft2020_12

      assert_equal JSONSchemer::Draft202012::BASE_URI.to_s, config.json_schema_uri
    end

    def test_configure_block
      with_configuration(validate_params: true, json_schema_version: :draft2020_12) do
        Verquest.configure do |config|
          config.validate_params = false
          config.json_schema_version = :draft7
        end

        refute Verquest.configuration.validate_params
        assert_equal :draft7, Verquest.configuration.json_schema_version
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module Verquest
  module Properties
    class FieldTest < Minitest::Test
      include ConfigurationTestHelper

      ::FieldTestReferenceClass = Class.new(Verquest::Base) do
        version "2025-06" do
          field :reference_field, type: :string, required: true, description: "A test field"
        end
      end

      def test_to_schema
        field = Field.new(
          name: :test_field,
          type: :string,
          required: true,
          description: "A test field"
        )

        expected_schema = {
          "test_field" => {
            "type" => "string",
            "description" => "A test field"
          }
        }

        assert_equal expected_schema, field.to_schema
      end

      def test_to_validation_schema
        field = Field.new(
          name: :test_field,
          type: :string,
          required: true,
          description: "A test field"
        )

        expected_schema = {
          "test_field" => {
            "type" => "string",
            "description" => "A test field"
          }
        }

        assert_equal expected_schema, field.to_validation_schema(version: "2025-06")
      end

      def test_mapping_without_map
        field = Field.new(
          name: :test_field,
          type: :string,
          required: true,
          description: "A test field"
        )

        mapping = {}
        field.mapping(key_prefix: [], value_prefix: [], mapping: mapping)

        expected_mapping = {
          "test_field" => "test_field"
        }

        assert_equal expected_mapping, mapping
      end

      def test_mapping_with_map
        field = Field.new(
          name: :test_field,
          type: :string,
          required: true,
          map: "another_field",
          description: "A test field"
        )

        mapping = {}
        field.mapping(key_prefix: [], value_prefix: [], mapping: mapping)

        expected_mapping = {
          "test_field" => "another_field"
        }

        assert_equal expected_mapping, mapping
      end

      def test_custom_field_type
        custom_types = {
          custom_type: {
            type: "string",
            schema_options: {format: "custom", pattern: /\Acustom_\w+\z/, min_length: 5, max_length: 20}
          }
        }

        with_configuration(custom_field_types: custom_types) do
          field = Field.new(
            name: :custom_field,
            type: :custom_type,
            required: true,
            description: "A custom field"
          )

          expected_schema = {
            "custom_field" => {
              "type" => "string",
              "format" => "custom",
              "pattern" => /\Acustom_\w+\z/,
              "minLength" => 5,
              "maxLength" => 20,
              "description" => "A custom field"
            }
          }

          assert_equal expected_schema, field.to_schema
        end
      end

      def test_custom_field_type_without_schema_options
        custom_types = {simple_custom: {type: "string"}}

        with_configuration(custom_field_types: custom_types) do
          field = Field.new(
            name: :simple_field,
            type: :simple_custom,
            required: true
          )

          expected_schema = {"simple_field" => {"type" => "string"}}

          assert_equal expected_schema, field.to_schema
        end
      end

      def test_custom_field_type_with_required_override
        custom_types = {required_type: {type: "string", required: true}}

        with_configuration(custom_field_types: custom_types) do
          field = Field.new(
            name: :required_field,
            type: :required_type,
            required: false # This should be overridden by custom type
          )

          assert field.required
        end
      end

      def test_invalid_type_raises_error
        error = assert_raises(ArgumentError) do
          Field.new(name: :test_field, type: :invalid_type)
        end

        assert_match(/Type must be one of/, error.message)
      end

      def test_map_to_root_raises_error
        error = assert_raises(ArgumentError) do
          Field.new(name: :test_field, type: :string, map: "/")
        end

        assert_equal "You can not map fields to the root without a name", error.message
      end
    end
  end
end

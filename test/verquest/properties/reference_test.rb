# frozen_string_literal: true

require "test_helper"

module Verquest
  module Properties
    class ReferenceTest < Minitest::Test
      ::ReferenceClass = Class.new(Verquest::Base) do
        version "2025-06" do
          field :reference_field, type: :string, required: true, description: "A test field"
        end
      end

      def test_to_schema_without_property
        reference = Reference.new(
          name: :test_field,
          from: ReferenceClass
        )

        expected_schema = {
          test_field: {
            "$ref": "#/components/schemas/ReferenceClass"
          }
        }

        assert_equal expected_schema, reference.to_schema
      end

      def test_to_schema_with_property
        reference = Reference.new(
          name: :test_field,
          from: ReferenceClass,
          property: :reference_field
        )

        expected_schema = {
          test_field: {
            "$ref": "#/components/schemas/ReferenceClass/properties/reference_field"
          }
        }

        assert_equal expected_schema, reference.to_schema
      end

      def test_to_validation_schema_without_property
        reference = Reference.new(
          name: :test_field,
          from: ReferenceClass
        )

        expected_schema = {
          test_field: {
            type: :object,
            description: nil,
            required: [:reference_field],
            properties: {
              reference_field: {
                type: :string,
                description: "A test field"
              }
            }
          }
        }

        assert_equal expected_schema, reference.to_validation_schema(version: "2025-06")
      end

      def test_to_validation_schema_with_property
        reference = Reference.new(
          name: :test_field,
          from: ReferenceClass,
          property: :reference_field
        )

        expected_schema = {
          test_field: {
            type: :string,
            description: "A test field"
          }
        }

        assert_equal expected_schema, reference.to_validation_schema(version: "2025-06")
      end

      def test_mapping_without_property
        reference = Reference.new(
          name: :test_field,
          from: ReferenceClass
        )

        mapping = {}
        reference.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: "2025-06")

        expected_mapping = {
          "test_field.reference_field" => "test_field.reference_field"
        }

        assert_equal expected_mapping, mapping
      end

      def test_mapping_without_property_with_map
        reference = Reference.new(
          name: :test_field,
          from: ReferenceClass,
          map: "referenced_object"
        )

        mapping = {}
        reference.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: "2025-06")

        expected_mapping = {
          "test_field.reference_field" => "referenced_object.reference_field"
        }

        assert_equal expected_mapping, mapping
      end

      def test_mapping_with_property_that_is_field
        reference = Reference.new(
          name: :test_field,
          from: ReferenceClass,
          property: :reference_field
        )

        mapping = {}
        reference.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: "2025-06")

        expected_mapping = {
          "test_field" => "test_field"
        }

        assert_equal expected_mapping, mapping
      end

      def test_mapping_with_property_that_is_field_with_map
        reference = Reference.new(
          name: :test_field,
          from: ReferenceClass,
          property: :reference_field,
          map: "single_referenced_field"
        )

        mapping = {}
        reference.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: "2025-06")

        expected_mapping = {
          "test_field" => "single_referenced_field"
        }

        assert_equal expected_mapping, mapping
      end
    end
  end
end

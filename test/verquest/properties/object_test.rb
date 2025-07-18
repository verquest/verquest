# frozen_string_literal: true

require "test_helper"

module Verquest
  module Properties
    class ObjectTest < Minitest::Test
      ::ObjectTestReferenceClass = Class.new(Verquest::Base) do
        version "2025-06" do
          field :reference_field, type: :string, required: true, description: "A test field"
        end
      end

      def test_to_schema
        object = Object.new(
          name: :test_field,
          required: true,
          description: "A test field"
        )

        sub_field = Field.new(
          name: :sub_field,
          type: :integer,
          required: true
        )
        object.add(sub_field)

        sub_reference = Reference.new(
          name: :reference_field,
          from: ::ObjectTestReferenceClass,
          property: :reference_field,
          required: true
        )
        object.add(sub_reference)

        sub_collection = Collection.new(
          name: :sub_collection,
          item: ::ObjectTestReferenceClass
        )
        object.add(sub_collection)

        expected_schema = {
          "test_field" => {
            "type" => "object",
            "required" => ["sub_field", "reference_field"],
            "properties" => {
              "sub_field" => {
                "type" => "integer"
              },
              "reference_field" => {
                "$ref" => "#/components/schemas/ObjectTestReferenceClass/properties/reference_field"
              },
              "sub_collection" => {
                "type" => "array",
                "items" => {
                  "$ref" => "#/components/schemas/ObjectTestReferenceClass"
                }
              }
            },
            "description" => "A test field",
            "additionalProperties" => false
          }
        }

        assert_equal expected_schema, object.to_schema
      end

      def test_to_validation_schema
        object = Object.new(
          name: :test_field,
          required: true,
          description: "A test field"
        )

        sub_field = Field.new(
          name: :sub_field,
          type: :integer,
          required: true
        )
        object.add(sub_field)

        sub_reference = Reference.new(
          name: :reference_field,
          from: ::ObjectTestReferenceClass,
          property: :reference_field,
          required: true
        )
        object.add(sub_reference)

        sub_collection = Collection.new(
          name: :sub_collection,
          item: ::ObjectTestReferenceClass
        )
        object.add(sub_collection)

        expected_schema = {
          "test_field" => {
            "type" => "object",
            "required" => ["sub_field", "reference_field"],
            "properties" => {
              "sub_field" => {
                "type" => "integer"
              },
              "reference_field" => {"type" => "string", "description" => "A test field"},
              "sub_collection" => {
                "type" => "array",
                "items" => {
                  "type" => "object",
                  "description" => nil,
                  "required" => ["reference_field"],
                  "properties" => {
                    "reference_field" => {"type" => "string", "description" => "A test field"}
                  },
                  "additionalProperties" => false
                }
              }
            },
            "additionalProperties" => false,
            "description" => "A test field"
          }
        }

        assert_equal expected_schema, object.to_validation_schema(version: "2025-06")
      end

      def test_mapping
        object = Object.new(
          name: :test_field,
          required: true,
          description: "A test field"
        )

        sub_field = Field.new(
          name: :sub_field,
          type: :integer,
          required: true,
          map: "/now_as_root_field"
        )
        object.add(sub_field)

        sub_reference = Reference.new(
          name: :reference_field,
          from: ::ObjectTestReferenceClass,
          property: :reference_field,
          required: true,
          map: "/test_field"
        )
        object.add(sub_reference)

        sub_collection = Collection.new(
          name: :sub_collection,
          item: ::ObjectTestReferenceClass,
          map: "/collection"
        )
        object.add(sub_collection)

        mapping = {}
        object.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: "2025-06")

        expected_mapping = {
          "test_field/sub_field" => "now_as_root_field",
          "test_field/reference_field" => "test_field",
          "test_field/sub_collection[]/reference_field" => "collection[]/reference_field"
        }

        assert_equal expected_mapping, mapping
      end
    end
  end
end

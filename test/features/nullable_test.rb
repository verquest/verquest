# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/nullable_request"

module Verquest
  class NullableTest < Minitest::Test
    def test_schema
      schema = NullableRequest.to_schema(version: "2025-06")

      expected_schema = {
        "type" => "object",
        "description" => "This is a simple request with nullable properties for testing purposes.",
        "required" => [],
        "properties" => {
          "array" => {"type" => %w[array null], "items" => {"type" => "string"}},
          "collection_with_item" => {"type" => %w[array null], "items" => {"$ref" => "#/components/schemas/ReferencedRequest"}},
          "collection_with_object" => {"type" => %w[array null], "items" => {"type" => "object", "required" => [], "properties" => {"field" => {"type" => "string"}}, "additionalProperties" => false}},
          "field" => {"type" => %w[string null]},
          "object" => {
            "type" => %w[object null],
            "required" => [],
            "properties" => {
              "field" => {"type" => "string"}
            },
            "additionalProperties" => false
          },
          "referenced_object" => {"oneOf" => [{"$ref" => "#/components/schemas/ReferencedRequest"}, {"type" => "null"}]},
          "referenced_field" => {"oneOf" => [{"$ref" => "#/components/schemas/ReferencedRequest/properties/simple_field"}, {"type" => "null"}]}
        },
        "additionalProperties" => false
      }

      assert_equal expected_schema, schema
    end

    def test_validation_schema
      assert NullableRequest.valid_schema?(version: "2025-06")

      validation_schema = NullableRequest.to_validation_schema(version: "2025-06")

      expected_validation_schema = {
        "type" => "object",
        "description" => "This is a simple request with nullable properties for testing purposes.",
        "required" => [],
        "properties" => {
          "array" => {"type" => %w[array null], "items" => {"type" => "string"}},
          "collection_with_item" => {"type" => %w[array null], "items" => {"type" => "object", "description" => "This is an another example for testing purposes.", "required" => %w[simple_field nested], "properties" => {"simple_field" => {"type" => "string", "description" => "The simple field"}, "nested" => {"type" => "object", "required" => %w[nested_field_2], "properties" => {"nested_field_1" => {"type" => "string", "description" => "This is a nested field"}, "nested_field_2" => {"type" => "string", "description" => "This is another nested field"}}, "additionalProperties" => false}}, "additionalProperties" => false}},
          "collection_with_object" => {"type" => %w[array null], "items" => {"type" => "object", "required" => [], "properties" => {"field" => {"type" => "string"}}, "additionalProperties" => false}},
          "field" => {"type" => %w[string null]},
          "object" => {
            "type" => %w[object null],
            "required" => [],
            "properties" => {
              "field" => {"type" => "string"}
            },
            "additionalProperties" => false
          },
          "referenced_object" => {
            "type" => %w[object null],
            "description" => "This is an another example for testing purposes.",
            "required" => %w[simple_field nested],
            "properties" => {"simple_field" => {"type" => "string", "description" => "The simple field"}, "nested" => {"type" => "object", "required" => %w[nested_field_2], "properties" => {"nested_field_1" => {"type" => "string", "description" => "This is a nested field"}, "nested_field_2" => {"type" => "string", "description" => "This is another nested field"}}, "additionalProperties" => false}},
            "additionalProperties" => false
          },
          "referenced_field" => {"type" => %w[string null], "description" => "The simple field"}
        },
        "additionalProperties" => false
      }

      assert_equal expected_validation_schema, validation_schema
    end
  end
end

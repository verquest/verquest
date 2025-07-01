# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/simple_request"

module Verquest
  class DefaultAdditionalPropertiesTest < Minitest::Test
    def test_first_version
      validation_schema = SimpleRequest.to_validation_schema(version: "2025-06")

      expected_validation_schema = {
        "type" => "object",
        "description" => "This is a simple request for testing purposes.",
        "required" => ["email"], # name is required in this version
        "properties" => {
          "email" => {"type" => "string", "format" => "email"},
          "name" => {"type" => "string"},
          "address" => {
            "type" => "object",
            "required" => ["city"],
            "properties" => {
              "street" => {"type" => "string"},
              "city" => {"type" => "string"},
              "zip_code" => {"type" => "string"}
            },
            "additionalProperties" => true # set on the address object
          }
        },
        "additionalProperties" => true # set on the top level
      }

      assert_equal expected_validation_schema, validation_schema
    end

    def test_second_version
      validation_schema = SimpleRequest.to_validation_schema(version: "2025-08")

      expected_validation_schema = {
        "type" => "object",
        "description" => "This is a simple request for testing purposes.",
        "required" => ["email", "name"], # name is required in this version
        "properties" => {
          "email" => {"type" => "string", "format" => "email"},
          "address" => {
            "type" => "object",
            "required" => ["city"],
            "properties" => {
              "street" => {"type" => "string"},
              "city" => {"type" => "string"},
              "zip_code" => {"type" => "string"}
            },
            "additionalProperties" => true # set on the address object
          },
          "name" => {"type" => "string", "minLength" => 3, "maxLength" => 50}
        } # missing additional properties as they are set to nil in this version
      }

      assert_equal expected_validation_schema, validation_schema
    end
  end
end

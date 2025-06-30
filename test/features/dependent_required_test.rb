# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/dependent_required_request"

module Verquest
  class DefaultAdditionalPropertiesTest < Minitest::Test
    def test_schema
      schema = DependentRequiredRequest.to_schema(version: "2025-06")

      expected_schema = {
        "type" => "object",
        "description" => "This is a simple request with nullable properties for testing purposes.",
        "required" => ["name"],
        "dependentRequired" => {"credit_card" => ["billing_address"]},
        "properties" => {
          "name" => {"type" => "string"},
          "credit_card" => {"type" => "number"},
          "billing_address" => {"type" => "string"}
        },
        "additionalProperties" => false
      }

      assert_equal expected_schema, schema
    end

    def test_validation_schema
      assert DependentRequiredRequest.valid_schema?(version: "2025-06")

      validation_schema = DependentRequiredRequest.to_validation_schema(version: "2025-06")

      expected_validation_schema = {
        "type" => "object",
        "description" => "This is a simple request with nullable properties for testing purposes.",
        "required" => ["name"],
        "dependentRequired" => {"credit_card" => ["billing_address"]},
        "properties" => {
          "name" => {"type" => "string"},
          "credit_card" => {"type" => "number"},
          "billing_address" => {"type" => "string"}
        },
        "additionalProperties" => false
      }

      assert_equal expected_validation_schema, validation_schema
    end

    def test_process_valid_params
      params = {
        "name" => "John Doe",
        "credit_card" => 1234567890123456,
        "billing_address" => "123 Main St"
      }

      result = DependentRequiredRequest.process(params, version: "2025-06")

      assert_equal params, result
    end

    def test_process_valid_params_without_dependents
      params = {
        "name" => "John Doe",
        "billing_address" => "123 Main St"
      }

      result = DependentRequiredRequest.process(params, version: "2025-06")

      assert_equal params, result
    end

    def test_process_invalid_params
      params = {
        "credit_card" => 1234567890123456
      }

      expected_error_messages = [
        "object at root is missing required properties: name",
        "object at `/credit_card` is missing required `dependentRequired` properties"
      ]

      error = assert_raises(Verquest::InvalidParamsError) do
        DependentRequiredRequest.process(params, version: "2025-06")
      end

      assert_equal expected_error_messages, error.errors.map { _1[:message] }
    end
  end
end

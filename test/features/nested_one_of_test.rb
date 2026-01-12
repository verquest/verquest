# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/order_request"

# Tests for nested oneOf with discriminator
class Verquest::NestedOneOfTest < Minitest::Test
  def test_schema
    schema = OrderRequest.to_schema(version: "2025-06")

    expected_schema = {
      "type" => "object",
      "required" => %w[order_id amount payment],
      "properties" => {
        "order_id" => {"type" => "string"},
        "amount" => {"type" => "number"},
        "payment" => {
          "oneOf" => [
            {"$ref" => "#/components/schemas/CardPaymentComponent"},
            {"$ref" => "#/components/schemas/BankPaymentComponent"}
          ],
          "discriminator" => {
            "propertyName" => "method",
            "mapping" => {
              "card" => "#/components/schemas/CardPaymentComponent",
              "bank" => "#/components/schemas/BankPaymentComponent"
            }
          }
        }
      },
      "additionalProperties" => false
    }

    assert_equal expected_schema, schema
  end

  def test_valid_schema
    assert OrderRequest.valid_schema?(version: "2025-06")
  end

  def test_validation_schema_structure
    validation_schema = OrderRequest.to_validation_schema(version: "2025-06")

    assert_equal "object", validation_schema["type"]
    assert_equal %w[order_id amount payment], validation_schema["required"]
    assert_equal({"type" => "string"}, validation_schema["properties"]["order_id"])
  end

  def test_validation_schema_amount
    validation_schema = OrderRequest.to_validation_schema(version: "2025-06")

    assert_equal({"type" => "number"}, validation_schema["properties"]["amount"])
  end

  def test_validation_schema_payment
    validation_schema = OrderRequest.to_validation_schema(version: "2025-06")

    # Validation schema omits discriminator (OpenAPI extension, not used by JSON Schema validators)
    expected_payment_schema = {
      "oneOf" => [
        {
          "type" => "object",
          "required" => %w[method card_number expiry],
          "properties" => {
            "method" => {"const" => "card"},
            "card_number" => {"type" => "string"},
            "expiry" => {"type" => "string"},
            "cvv" => {"type" => "string"}
          },
          "additionalProperties" => false
        },
        {
          "type" => "object",
          "required" => %w[method account_number routing_number],
          "properties" => {
            "method" => {"const" => "bank"},
            "account_number" => {"type" => "string"},
            "routing_number" => {"type" => "string"}
          },
          "additionalProperties" => false
        }
      ]
    }

    assert_equal expected_payment_schema, validation_schema["properties"]["payment"]
  end

  def test_mapping
    mapping = OrderRequest.mapping(version: "2025-06")

    expected_mapping = {
      "_discriminator" => "payment/method",
      "card" => {
        "order_id" => "order_id",
        "amount" => "amount",
        "payment/method" => "payment/method",
        "payment/card_number" => "payment/card_number",
        "payment/expiry" => "payment/expiry",
        "payment/cvv" => "payment/cvv"
      },
      "bank" => {
        "order_id" => "order_id",
        "amount" => "amount",
        "payment/method" => "payment/method",
        "payment/account_number" => "payment/account_number",
        "payment/routing_number" => "payment/routing_number"
      }
    }

    assert_equal expected_mapping, mapping
  end

  def test_external_mapping
    external_mapping = OrderRequest.external_mapping(version: "2025-06")

    expected_mapping = {
      "_discriminator" => "payment/method",
      "card" => {
        "order_id" => "order_id",
        "amount" => "amount",
        "payment/method" => "payment/method",
        "payment/card_number" => "payment/card_number",
        "payment/expiry" => "payment/expiry",
        "payment/cvv" => "payment/cvv"
      },
      "bank" => {
        "order_id" => "order_id",
        "amount" => "amount",
        "payment/method" => "payment/method",
        "payment/account_number" => "payment/account_number",
        "payment/routing_number" => "payment/routing_number"
      }
    }

    assert_equal expected_mapping, external_mapping
  end

  def test_process_card_payment
    params = {
      "order_id" => "ORD-123",
      "amount" => 99.99,
      "payment" => {
        "method" => "card",
        "card_number" => "4111111111111111",
        "expiry" => "12/25",
        "cvv" => "123"
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = OrderRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    expected_result = {
      "order_id" => "ORD-123",
      "amount" => 99.99,
      "payment" => {
        "method" => "card",
        "card_number" => "4111111111111111",
        "expiry" => "12/25",
        "cvv" => "123"
      }
    }

    assert_equal expected_result, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_bank_payment
    params = {
      "order_id" => "ORD-456",
      "amount" => 150.00,
      "payment" => {
        "method" => "bank",
        "account_number" => "123456789",
        "routing_number" => "987654321"
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = OrderRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    expected_result = {
      "order_id" => "ORD-456",
      "amount" => 150.00,
      "payment" => {
        "method" => "bank",
        "account_number" => "123456789",
        "routing_number" => "987654321"
      }
    }

    assert_equal expected_result, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_invalid_payment_method
    params = {
      "order_id" => "ORD-789",
      "amount" => 50.00,
      "payment" => {
        "method" => "crypto",
        "wallet" => "0x123..."
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = OrderRequest.process(params, version: "2025-06", validate: true)

    refute_predicate result, :success?
    # JSONSchemer validates each schema in oneOf and reports const validation errors
    assert_equal "const", result.errors.first[:type]
    assert_equal "/payment/method", result.errors.first[:pointer]
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_missing_required_payment_field
    params = {
      "order_id" => "ORD-999",
      "amount" => 75.00,
      "payment" => {
        "method" => "card",
        "card_number" => "4111111111111111"
        # missing expiry
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = OrderRequest.process(params, version: "2025-06", validate: true)

    refute_predicate result, :success?
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end
end

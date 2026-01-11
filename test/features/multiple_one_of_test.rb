# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/card_payment_component"
require_relative "../support/examples/bank_payment_component"
require_relative "../support/examples/standard_shipping_component"
require_relative "../support/examples/express_shipping_component"
require_relative "../support/examples/with_id_component"
require_relative "../support/examples/without_id_component"

# Tests for multiple named oneOf properties in a single version
class Verquest::MultipleOneOfTest < Minitest::Test
  class OrderWithPaymentAndShipping < Verquest::Base
    version "2025-06" do
      field :order_id, type: :string, required: true
      field :amount, type: :number, required: true

      one_of name: :payment, discriminator: :method, required: true do
        reference :card, from: CardPaymentComponent
        reference :bank, from: BankPaymentComponent
      end

      one_of name: :shipping, discriminator: :type, required: true do
        reference :standard, from: StandardShippingComponent
        reference :express, from: ExpressShippingComponent
      end

      one_of name: :metadata do
        reference :with_id, from: WithIdComponent
        reference :without_id, from: WithoutIdComponent
      end
    end
  end

  def test_schema_type_and_required
    schema = OrderWithPaymentAndShipping.to_schema(version: "2025-06")

    assert_equal "object", schema["type"]
    assert_equal %w[order_id amount payment shipping], schema["required"]
  end

  def test_schema_payment_one_of
    schema = OrderWithPaymentAndShipping.to_schema(version: "2025-06")
    payment = schema["properties"]["payment"]

    assert payment.key?("oneOf")
    assert_equal "method", payment.dig("discriminator", "propertyName")
  end

  def test_schema_shipping_one_of
    schema = OrderWithPaymentAndShipping.to_schema(version: "2025-06")
    shipping = schema["properties"]["shipping"]

    assert shipping.key?("oneOf")
    assert_equal "type", shipping.dig("discriminator", "propertyName")
  end

  def test_validation_schema_payment_one_of
    validation_schema = OrderWithPaymentAndShipping.to_validation_schema(version: "2025-06")
    payment = validation_schema["properties"]["payment"]

    assert payment.key?("oneOf")
    assert_equal 2, payment["oneOf"].size
  end

  def test_validation_schema_shipping_one_of
    validation_schema = OrderWithPaymentAndShipping.to_validation_schema(version: "2025-06")
    shipping = validation_schema["properties"]["shipping"]

    assert shipping.key?("oneOf")
    assert_equal 2, shipping["oneOf"].size
  end

  def test_mapping_base_properties
    mapping = OrderWithPaymentAndShipping.mapping(version: "2025-06")

    assert_equal({"order_id" => "order_id", "amount" => "amount"}, mapping.slice("order_id", "amount"))
  end

  def test_mapping_one_ofs_count
    mapping = OrderWithPaymentAndShipping.mapping(version: "2025-06")

    assert_equal 3, mapping["_oneOfs"].size
  end

  def test_mapping_payment_one_of
    mapping = OrderWithPaymentAndShipping.mapping(version: "2025-06")
    payment_mapping = mapping["_oneOfs"].find { |m| m["_discriminator"] == "payment/method" }

    assert payment_mapping, "Expected payment oneOf mapping"
    assert_equal %w[bank card], (payment_mapping.keys - %w[_discriminator]).sort
  end

  def test_mapping_shipping_one_of
    mapping = OrderWithPaymentAndShipping.mapping(version: "2025-06")
    shipping_mapping = mapping["_oneOfs"].find { |m| m["_discriminator"] == "shipping/type" }

    assert shipping_mapping, "Expected shipping oneOf mapping"
    assert_equal %w[express standard], (shipping_mapping.keys - %w[_discriminator]).sort
  end

  def test_mapping_metadata_one_of
    mapping = OrderWithPaymentAndShipping.mapping(version: "2025-06")
    metadata_mapping = mapping["_oneOfs"].find { |m| m["_variant_path"] == "metadata" }

    assert metadata_mapping, "Expected metadata oneOf mapping"
    assert metadata_mapping.key?("_variant_schemas")
  end

  def test_process_card_payment_standard_shipping
    params = {
      "order_id" => "order-123",
      "amount" => 99.99,
      "payment" => {
        "method" => "card",
        "card_number" => "4111111111111111",
        "expiry" => "12/25"
      },
      "shipping" => {
        "type" => "standard",
        "carrier" => "UPS",
        "tracking_number" => "1Z999AA10123456784"
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = OrderWithPaymentAndShipping.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal params, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_bank_payment_express_shipping
    params = {
      "order_id" => "order-456",
      "amount" => 250.00,
      "payment" => {
        "method" => "bank",
        "account_number" => "123456789",
        "routing_number" => "987654321"
      },
      "shipping" => {
        "type" => "express",
        "service" => "FedEx Overnight",
        "delivery_date" => "2025-06-15"
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = OrderWithPaymentAndShipping.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal params, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_invalid_payment_discriminator
    params = {
      "order_id" => "order-789",
      "amount" => 50.00,
      "payment" => {
        "method" => "crypto", # Invalid discriminator
        "wallet" => "abc123"
      },
      "shipping" => {
        "type" => "standard",
        "carrier" => "USPS"
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = OrderWithPaymentAndShipping.process(params, version: "2025-06", validate: true)

    refute_predicate result, :success?
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_invalid_shipping_discriminator
    params = {
      "order_id" => "order-789",
      "amount" => 50.00,
      "payment" => {
        "method" => "card",
        "card_number" => "4111111111111111",
        "expiry" => "12/25"
      },
      "shipping" => {
        "type" => "drone", # Invalid discriminator
        "eta" => "5 minutes"
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = OrderWithPaymentAndShipping.process(params, version: "2025-06", validate: true)

    refute_predicate result, :success?
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_valid_schema
    assert OrderWithPaymentAndShipping.valid_schema?(version: "2025-06")
  end
end

# Tests for multiple oneOf without discriminators (schema inference)
class Verquest::MultipleOneOfWithoutDiscriminatorTest < Minitest::Test
  class MultiContentRequest < Verquest::Base
    version "2025-06" do
      field :request_id, type: :string, required: true

      one_of name: :primary_content do
        reference :with_id, from: WithIdComponent
        reference :without_id, from: WithoutIdComponent
      end

      one_of name: :secondary_content do
        reference :with_id, from: WithIdComponent
        reference :without_id, from: WithoutIdComponent
      end
    end
  end

  def test_mapping_one_ofs_count
    mapping = MultiContentRequest.mapping(version: "2025-06")

    assert_equal 2, mapping["_oneOfs"].size
  end

  def test_mapping_all_one_ofs_have_variant_schemas
    mapping = MultiContentRequest.mapping(version: "2025-06")

    mapping["_oneOfs"].each do |one_of_mapping|
      assert one_of_mapping.key?("_variant_schemas"), "Expected _variant_schemas for schema inference"
      assert one_of_mapping.key?("_variant_path")
    end
  end

  def test_process_both_with_id
    params = {
      "request_id" => "req-001",
      "primary_content" => {
        "id" => "primary-1",
        "name" => "Primary Content",
        "value" => 100
      },
      "secondary_content" => {
        "id" => "secondary-1",
        "name" => "Secondary Content",
        "value" => 200
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = MultiContentRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal params, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_mixed_variants
    params = {
      "request_id" => "req-002",
      "primary_content" => {
        "id" => "primary-1",
        "name" => "Primary Content",
        "value" => 100
      },
      "secondary_content" => {
        "name" => "Secondary Content",
        "description" => "No ID here"
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = MultiContentRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal params, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_valid_schema
    assert MultiContentRequest.valid_schema?(version: "2025-06")
  end
end

# Tests for mixed discriminator and schema-inference oneOf
class Verquest::MixedMultipleOneOfTest < Minitest::Test
  class MixedRequest < Verquest::Base
    version "2025-06" do
      field :id, type: :string, required: true

      # OneOf with discriminator
      one_of name: :payment, discriminator: :method, required: true do
        reference :card, from: CardPaymentComponent
        reference :bank, from: BankPaymentComponent
      end

      # OneOf without discriminator (schema inference)
      one_of name: :metadata do
        reference :with_id, from: WithIdComponent
        reference :without_id, from: WithoutIdComponent
      end
    end
  end

  def test_mapping_one_ofs_count
    mapping = MixedRequest.mapping(version: "2025-06")

    assert_equal 2, mapping["_oneOfs"].size
  end

  def test_mapping_payment_one_of_with_discriminator
    mapping = MixedRequest.mapping(version: "2025-06")
    payment_mapping = mapping["_oneOfs"].find { |m| m.key?("_discriminator") }

    assert payment_mapping, "Expected payment oneOf with discriminator"
    assert_equal "payment/method", payment_mapping["_discriminator"]
  end

  def test_mapping_metadata_one_of_with_schema_inference
    mapping = MixedRequest.mapping(version: "2025-06")
    metadata_mapping = mapping["_oneOfs"].find { |m| m.key?("_variant_schemas") }

    assert metadata_mapping, "Expected metadata oneOf with variant schemas"
    assert_equal "metadata", metadata_mapping["_variant_path"]
  end

  def test_process_with_discriminator_and_schema_inference
    params = {
      "id" => "mixed-001",
      "payment" => {
        "method" => "card",
        "card_number" => "4111111111111111",
        "expiry" => "12/25"
      },
      "metadata" => {
        "id" => "meta-1",
        "name" => "Metadata with ID",
        "value" => 42
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = MixedRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal params, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_valid_schema
    assert MixedRequest.valid_schema?(version: "2025-06")
  end
end

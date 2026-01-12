# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/card_payment_component"
require_relative "../../support/examples/bank_payment_component"
require_relative "../../support/examples/with_id_component"
require_relative "../../support/examples/without_id_component"

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

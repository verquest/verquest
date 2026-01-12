# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/card_payment_component"
require_relative "../support/examples/bank_payment_component"

# Tests for nested oneOf with map parameter
class Verquest::NestedOneOfWithMapTest < Minitest::Test
  class MappedOrderRequest < Verquest::Base
    version "2025-06" do
      field :order_id, type: :string, required: true, map: "id"
      field :amount, type: :number, required: true

      one_of name: :payment, discriminator: "method", required: true, map: "payment_details" do
        reference :card, from: CardPaymentComponent
        reference :bank, from: BankPaymentComponent
      end
    end
  end

  def test_mapping_with_map_parameter
    mapping = MappedOrderRequest.mapping(version: "2025-06")

    expected_mapping = {
      "_discriminator" => "payment/method",
      "card" => {
        "order_id" => "id",
        "amount" => "amount",
        "payment/method" => "payment_details/method",
        "payment/card_number" => "payment_details/card_number",
        "payment/expiry" => "payment_details/expiry",
        "payment/cvv" => "payment_details/cvv"
      },
      "bank" => {
        "order_id" => "id",
        "amount" => "amount",
        "payment/method" => "payment_details/method",
        "payment/account_number" => "payment_details/account_number",
        "payment/routing_number" => "payment_details/routing_number"
      }
    }

    assert_equal expected_mapping, mapping
  end

  def test_process_with_map_transformation
    params = {
      "order_id" => "ORD-MAP-123",
      "amount" => 199.99,
      "payment" => {
        "method" => "card",
        "card_number" => "4111111111111111",
        "expiry" => "12/25"
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = MappedOrderRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    expected_result = {
      "id" => "ORD-MAP-123",
      "amount" => 199.99,
      "payment_details" => {
        "method" => "card",
        "card_number" => "4111111111111111",
        "expiry" => "12/25"
      }
    }

    assert_equal expected_result, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end
end

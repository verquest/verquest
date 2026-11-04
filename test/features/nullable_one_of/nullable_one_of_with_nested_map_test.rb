# frozen_string_literal: true

require "test_helper"

# Tests a null nullable oneOf mapped to a nested target path
class Verquest::NullableOneOfWithNestedMapTest < Minitest::Test
  class PaymentRequest < Verquest::Base
    version "2025-06" do
      field :id, type: :string

      one_of name: :payment, discriminator: :method, nullable: true, map: "billing/payment" do
        object :card do
          const :method, value: "card"
          field :number, type: :string
        end

        object :bank do
          const :method, value: "bank"
          field :iban, type: :string
        end
      end
    end
  end

  def test_process
    cases = {
      "null" => [
        {"id" => "1", "payment" => nil},
        {"id" => "1", "billing" => {"payment" => nil}}
      ],
      "variant" => [
        {"id" => "1", "payment" => {"method" => "card", "number" => "4"}},
        {"id" => "1", "billing" => {"payment" => {"method" => "card", "number" => "4"}}}
      ]
    }

    results = cases.transform_values { |(params, _)| PaymentRequest.process(params, version: "2025-06") }

    assert_equal cases.transform_values(&:last), results
  end
end

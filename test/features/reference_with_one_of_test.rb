# frozen_string_literal: true

require "test_helper"

# Tests references and collection items to classes that hold a oneOf
class Verquest::ReferenceWithOneOfTest < Minitest::Test
  class PaymentComponent < Verquest::Base
    version "2025-06" do
      field :amount, type: :number

      one_of name: :method, discriminator: :type, nullable: true do
        object :card do
          const :type, value: "card"
          field :number, type: :string
        end

        object :bank do
          const :type, value: "bank"
          field :iban, type: :string, map: "account"
        end
      end
    end
  end

  class ShapeComponent < Verquest::Base
    version "2025-06" do
      one_of do
        object :square do
          field :side, type: :number, required: true
        end

        object :circle do
          field :radius, type: :number, required: true
        end
      end
    end
  end

  class OrderRequest < Verquest::Base
    version "2025-06" do
      field :id, type: :string
      reference :payment, from: PaymentComponent, map: "billing"
      reference :shape, from: ShapeComponent
      collection :payments, item: PaymentComponent
      collection :shapes, item: ShapeComponent, map: "figures"
    end
  end

  def test_process
    params = {
      "id" => "1",
      "payment" => {"amount" => 5, "method" => {"type" => "bank", "iban" => "CZ1"}},
      "shape" => {"radius" => 2},
      "payments" => [{"amount" => 1, "method" => {"type" => "card", "number" => "4"}}, {"amount" => 2, "method" => nil}],
      "shapes" => [{"side" => 1}, {"radius" => 3}]
    }

    expected = {
      "id" => "1",
      "billing" => {"amount" => 5, "method" => {"type" => "bank", "account" => "CZ1"}},
      "shape" => {"radius" => 2},
      "payments" => [{"amount" => 1, "method" => {"type" => "card", "number" => "4"}}, {"amount" => 2, "method" => nil}],
      "figures" => [{"side" => 1}, {"radius" => 3}]
    }

    assert_equal expected, OrderRequest.process(params, version: "2025-06")
  end

  def test_external_mapping
    external = OrderRequest.external_mapping(version: "2025-06")
    bank = external["_oneOfs"].find { |one_of| one_of.key?("bank") && one_of["bank"].key?("billing/method/account") }

    assert_equal({"id" => "id", "billing/amount" => "payment/amount", "payments[]/amount" => "payments[]/amount"}, external.except("_oneOfs"))
    assert_equal "payment/method/iban", bank["bank"]["billing/method/account"]
  end
end

# frozen_string_literal: true

require "test_helper"

# Tests for a oneOf nested inside an object
class Verquest::OneOfInObjectTest < Minitest::Test
  class WrappedRequest < Verquest::Base
    version "2025-06" do
      field :id, type: :string

      object :wrapper, map: "box" do
        field :label, type: :string

        one_of name: :value, nullable: true do
          object :text do
            field :content, type: :string, required: true
          end

          object :number do
            field :amount, type: :number, required: true, map: "total"
          end
        end

        one_of name: :payment, discriminator: :method do
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
  end

  class CollectionRequest < Verquest::Base
    version "2025-06" do
      collection :entries, map: "records" do
        field :entry_id, type: :string

        object :body do
          field :kind, type: :string

          one_of name: :value do
            object(:text) { field :text, type: :string, required: true }
            object(:number) { field :amount, type: :number, required: true, map: "total" }
          end
        end
      end
    end
  end

  def test_process
    cases = {
      "inferred variant" => [
        {"id" => "1", "wrapper" => {"label" => "a", "value" => {"amount" => 5}}},
        {"id" => "1", "box" => {"label" => "a", "value" => {"total" => 5}}}
      ],
      "discriminated variant" => [
        {"wrapper" => {"payment" => {"method" => "bank", "iban" => "CZ1"}}},
        {"box" => {"payment" => {"method" => "bank", "iban" => "CZ1"}}}
      ],
      "both oneOfs" => [
        {"wrapper" => {"value" => {"content" => "x"}, "payment" => {"method" => "card", "number" => "4"}}},
        {"box" => {"value" => {"content" => "x"}, "payment" => {"method" => "card", "number" => "4"}}}
      ],
      "absent oneOfs" => [
        {"id" => "1", "wrapper" => {"label" => "a"}},
        {"id" => "1", "box" => {"label" => "a"}}
      ],
      "null oneOf" => [
        {"wrapper" => {"label" => "a", "value" => nil}},
        {"box" => {"label" => "a", "value" => nil}}
      ]
    }

    results = cases.transform_values { |(params, _)| WrappedRequest.process(params, version: "2025-06") }

    assert_equal cases.transform_values(&:last), results
  end

  def test_process_in_a_collection
    params = {"entries" => [
      {"entry_id" => "a", "body" => {"kind" => "k", "value" => {"amount" => 1}}},
      {"entry_id" => "b", "body" => {"value" => {"text" => "t"}}},
      {"entry_id" => "c"}
    ]}

    expected = {"records" => [
      {"entry_id" => "a", "body" => {"kind" => "k", "value" => {"total" => 1}}},
      {"entry_id" => "b", "body" => {"value" => {"text" => "t"}}},
      {"entry_id" => "c"}
    ]}

    assert_equal expected, CollectionRequest.process(params, version: "2025-06")
  end
end

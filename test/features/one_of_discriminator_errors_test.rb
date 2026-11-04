# frozen_string_literal: true

require "test_helper"

# Tests a missing or unknown discriminator value without validation
class Verquest::OneOfDiscriminatorErrorsTest < Minitest::Test
  class RootRequest < Verquest::Base
    version "2025-06" do
      one_of discriminator: :type do
        object :dog do
          const :type, value: "dog"
          field :bark, type: :boolean
        end

        object :cat do
          const :type, value: "cat"
          field :meow, type: :boolean
        end
      end
    end
  end

  class NestedRequest < Verquest::Base
    version "2025-06" do
      field :id, type: :string

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

  class CollectionRequest < Verquest::Base
    version "2025-06" do
      collection :pets do
        one_of discriminator: :type do
          object :dog do
            const :type, value: "dog"
            field :bark, type: :boolean
          end

          object :cat do
            const :type, value: "cat"
            field :meow, type: :boolean
          end
        end
      end
    end
  end

  def test_process
    cases = {
      "root without discriminator" => [RootRequest, {"meow" => true}],
      "root with unknown value" => [RootRequest, {"type" => "cow"}],
      "nested without discriminator" => [NestedRequest, {"payment" => {"number" => "4"}}],
      "nested with a metadata key as value" => [NestedRequest, {"payment" => {"method" => "_discriminator"}}],
      "nested without the oneOf" => [NestedRequest, {"id" => "1"}],
      "collection item without discriminator" => [CollectionRequest, {"pets" => [{"meow" => true}]}],
      "collection item with unknown value" => [CollectionRequest, {"pets" => [{"type" => "cow"}]}]
    }

    results = cases.transform_values do |(request, params)|
      request.process(params, version: "2025-06", validate: false)
    rescue Verquest::MappingError => e
      e.message
    end

    expected = {
      "root without discriminator" => "Missing discriminator \"type\" for oneOf.",
      "root with unknown value" => "Unknown discriminator value \"cow\" for oneOf. No matching variant found.",
      "nested without discriminator" => "Missing discriminator \"payment/method\" for oneOf.",
      "nested with a metadata key as value" => "Unknown discriminator value \"_discriminator\" for oneOf. No matching variant found.",
      "nested without the oneOf" => {"id" => "1"},
      "collection item without discriminator" => "Missing discriminator \"type\" for oneOf.",
      "collection item with unknown value" => "Unknown discriminator value \"cow\" for oneOf. No matching variant found."
    }

    assert_equal expected, results
  end
end

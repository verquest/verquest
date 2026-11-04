# frozen_string_literal: true

require "test_helper"

module Verquest
  # Tests the depends_on shorthand
  class ConditionsDependsOnTest < Minitest::Test
    include ConfigurationTestHelper

    def test_schema
      schema = build_request.to_schema(version: "2025-09")

      expected = {
        "if" => {"required" => %w[credit_card]},
        "then" => {"required" => %w[billing_address credit_card]},
        "else" => {"properties" => {"billing_address" => false}}
      }

      assert_equal expected, schema.slice("if", "then", "else")
      assert_equal %w[credit_card billing_address], schema["properties"].keys
    end

    def test_validation
      request = build_request

      assert_equal [{pointer: "", type: "required"}], errors(request, {"credit_card" => "4111"})
      assert_equal [{pointer: "/billing_address", type: "schema"}], errors(request, {"billing_address" => "Main St"})
      assert_empty errors(request, {"credit_card" => "4111", "billing_address" => "Main St"})
    end

    def test_condition_is_named
      assert_equal %w[card], build_request.resolve("2025-09").conditions.map(&:name)
    end

    private

    def build_request
      Class.new(Verquest::Base) do
        version "2025-09" do
          field :credit_card, type: :string

          depends_on :credit_card, :card do
            field :billing_address, type: :string, required: true
            present :credit_card
          end
        end
      end
    end

    def errors(request, params)
      with_configuration(validation_error_handling: :result) do
        result = request.process(params, version: "2025-09", validate: true)
        result.success? ? [] : result.errors.map { |error| error.slice(:pointer, :type) }
      end
    end
  end
end

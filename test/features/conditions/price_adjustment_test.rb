# frozen_string_literal: true

require "test_helper"

module Verquest
  # Tests the price adjustment request rewritten with a condition
  #
  # Each validation failure must give exactly one error, under every JSON Schema
  # version that supports conditions.
  class ConditionsPriceAdjustmentTest < Minitest::Test
    include ConfigurationTestHelper

    DIALECTS = %i[openapi31 draft7 draft2020_12].freeze

    CASES = {
      "percentages over maximum" => [
        {"effective_from" => "2025-09-01", "percentages" => {"unit_types" => 10_000}},
        [{pointer: "/percentages/unit_types", type: "maximum"}]
      ],
      "zero percentage" => [
        {"effective_from" => "2025-09-01", "percentage" => 0},
        [{pointer: "/percentage", type: "not"}]
      ],
      "percentage and percentages" => [
        {"effective_from" => "2025-09-01", "percentage" => 5, "percentages" => {"unit_types" => 10}},
        [{pointer: "/percentage", type: "schema"}]
      ],
      "unknown key" => [
        {"effective_from" => "2025-09-01", "percentage" => 5, "bogus" => 1},
        [{pointer: "/bogus", type: "schema"}]
      ],
      "neither sent" => [
        {"effective_from" => "2025-09-01"},
        [{pointer: "", type: "required"}]
      ],
      "legacy variant" => [
        {"effective_from" => "2025-09-01", "percentage" => 5, "applies_to" => {"unit_types" => true}},
        []
      ],
      "per-type variant" => [
        {"effective_from" => "2025-09-01", "percentages" => {"unit_types" => 10}},
        []
      ]
    }.freeze

    def test_one_error_per_problem_in_each_dialect
      expected = DIALECTS.to_h { |dialect| [dialect, CASES.transform_values(&:last)] }

      actual = DIALECTS.to_h do |dialect|
        request = build_request(dialect)
        [dialect, CASES.transform_values { |(params, _)| errors(dialect, request, params) }]
      end

      assert_equal expected, actual
    end

    def test_update_does_not_require_percentage
      request = build_request(:openapi31, percentage_required: false)

      assert_empty errors(:openapi31, request, {"effective_from" => "2025-09-01"})
    end

    def test_schema
      schema = build_request(:openapi31).to_schema(version: "2025-09")

      expected = {
        "if" => {"required" => %w[percentages]},
        "then" => {"required" => %w[percentages], "properties" => {"percentage" => false, "applies_to" => false}},
        "else" => {"required" => %w[percentage], "properties" => {"percentages" => false}}
      }

      assert_equal %w[effective_from schedule percentages percentage applies_to], schema["properties"].keys
      assert_equal expected, schema.slice("if", "then", "else")
      assert_equal %w[effective_from], schema["required"]
    end

    def test_mapping_and_process
      request = build_request(:openapi31)

      expected_mapping = {
        "effective_from" => "effective_from", "schedule" => "schedule", "percentages/unit_types" => "percentages/unit_types",
        "percentage" => "percentage", "applies_to/unit_types" => "apply_to_unit_types"
      }

      assert_equal expected_mapping, request.mapping(version: "2025-09")
      assert_equal(
        {"effective_from" => "2025-09-01", "percentage" => 5, "apply_to_unit_types" => true},
        request.process({"effective_from" => "2025-09-01", "percentage" => 5, "applies_to" => {"unit_types" => true}}, version: "2025-09")
      )
      assert_equal(
        {"effective_from" => "2025-09-01", "percentages" => {"unit_types" => 10}},
        request.process({"effective_from" => "2025-09-01", "percentages" => {"unit_types" => 10}}, version: "2025-09")
      )
    end

    private

    def build_request(dialect, percentage_required: true)
      with_configuration(json_schema_version: dialect) do
        Class.new(Verquest::Base) do
          version "2025-09" do
            field :effective_from, type: :string, required: true
            field :schedule, type: :boolean

            condition :pricing do
              given { present :percentages }
              then_apply do
                object :percentages, required: true, min_properties: 1 do
                  field :unit_types, type: :number, maximum: 9999.99
                end
              end
              else_apply do
                field :percentage, type: :number, required: percentage_required, deprecated: true, not: {const: 0}
                object :applies_to, deprecated: true do
                  field :unit_types, type: :boolean, map: "/apply_to_unit_types"
                end
              end
            end
          end
        end
      end
    end

    def errors(dialect, request, params)
      with_configuration(json_schema_version: dialect, validation_error_handling: :result) do
        result = request.process(params, version: "2025-09", validate: true, remove_extra_root_keys: false)
        result.success? ? [] : result.errors.map { |error| error.slice(:pointer, :type) }
      end
    end
  end
end

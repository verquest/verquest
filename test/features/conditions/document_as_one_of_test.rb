# frozen_string_literal: true

require "test_helper"

module Verquest
  # Tests conditions documented as a oneOf
  #
  # `to_schema` renders one oneOf variant per branch, while the validation
  # schema keeps `if` / `then` / `else`. Both must accept the same payloads.
  class ConditionsDocumentAsOneOfTest < Minitest::Test
    include ConfigurationTestHelper

    DIALECTS = %i[draft7 draft2019_09 draft2020_12 openapi31].freeze

    PAYLOADS = [
      {"effective_from" => "2025-09-01", "percentages" => {"unit_types" => 10}},
      {"effective_from" => "2025-09-01", "percentages" => {"unit_types" => 10_000}},
      {"effective_from" => "2025-09-01", "percentages" => {}},
      {"effective_from" => "2025-09-01", "percentage" => 5},
      {"effective_from" => "2025-09-01", "percentage" => 5, "applies_to" => {"unit_types" => true}},
      {"effective_from" => "2025-09-01", "percentage" => 0},
      {"effective_from" => "2025-09-01", "percentage" => 5, "percentages" => {"unit_types" => 10}},
      {"effective_from" => "2025-09-01", "applies_to" => {"unit_types" => true}, "percentages" => {"unit_types" => 10}},
      {"effective_from" => "2025-09-01", "percentage" => 5, "bogus" => 1},
      {"effective_from" => "2025-09-01"},
      {"percentage" => 5},
      {}
    ].freeze

    # Every rule type in `given`, including one on a property only a branch
    # declares (the else variant then forbids it, so `not` is left out) and
    # `satisfies` on a keyword the field already sets (`age` has `minimum: 0`)
    GIVEN_RULES = {
      present: -> { present :kind },
      present_branch_property: -> { present :vat_id },
      absent: -> { absent :note },
      equals: -> { equals :kind, "company" },
      value_in: -> { value_in :kind, %w[company person] },
      satisfies: -> { satisfies :age, minimum: 18 },
      any: lambda do
        any do
          equals :kind, "company"
          satisfies :age, minimum: 18
        end
      end,
      none: lambda do
        none do
          equals :kind, "person"
          present :note
        end
      end,
      several_rules: lambda do
        present :note
        equals :kind, "company"
      end
    }.freeze

    # Values for every property in the rule requests, nil meaning absent
    RULE_VALUES = {
      "kind" => [nil, "company", "person"],
      "age" => [nil, -1, 17, 30],
      "note" => [nil, "x"],
      "vat_id" => [nil, "1"],
      "reason" => [nil, "y"]
    }.freeze

    def test_schema
      schema = build_request.to_schema(version: "2025-09")

      expected = {
        "description" => "Price adjustment",
        "oneOf" => [
          {
            "type" => "object",
            "title" => "Per-type percentages",
            "required" => %w[effective_from percentages],
            "properties" => {
              "effective_from" => {"type" => "string"},
              "percentages" => {
                "type" => "object",
                "required" => [],
                "properties" => {"unit_types" => {"type" => "number", "maximum" => 9999.99}},
                "additionalProperties" => false,
                "minProperties" => 1
              }
            },
            "additionalProperties" => false
          },
          {
            "type" => "object",
            "title" => "Shared percentage",
            "description" => "Use percentages instead",
            "deprecated" => true,
            "required" => %w[effective_from percentage],
            "properties" => {
              "effective_from" => {"type" => "string"},
              "percentage" => {"type" => "number", "not" => {"const" => 0}},
              "applies_to" => {
                "type" => "object",
                "required" => [],
                "properties" => {"unit_types" => {"type" => "boolean"}},
                "additionalProperties" => false
              }
            },
            "additionalProperties" => false
          }
        ]
      }

      assert_equal expected, schema
    end

    def test_validation_schema_keeps_if_then_else
      schema = build_request.to_validation_schema(version: "2025-09")

      refute schema.key?("oneOf")
      assert_equal({"required" => %w[percentages]}, schema["if"])
    end

    def test_schema_is_valid_for_supported_dialects
      valid = DIALECTS.to_h do |dialect|
        schema = build_request(dialect).to_schema(version: "2025-09")
        [dialect, with_configuration(json_schema_version: dialect) { JSONSchemer.valid_schema?(schema, meta_schema: Verquest.configuration.json_schema_uri) }]
      end

      assert_equal DIALECTS.to_h { |dialect| [dialect, true] }, valid
    end

    def test_schema_and_validation_schema_accept_the_same_payloads
      DIALECTS.each do |dialect|
        request = build_request(dialect)

        assert_equal accepted(dialect, request.to_validation_schema(version: "2025-09")), accepted(dialect, request.to_schema(version: "2025-09")), dialect
      end
    end

    def test_every_given_rule_documents_the_same_payloads
      payloads = rule_payloads

      results = GIVEN_RULES.each_with_object({}) do |(rule, given_block), mismatches|
        %i[draft2020_12 openapi31].each do |dialect|
          request = build_rule_request(dialect, given_block)
          validation = accepted(dialect, request.to_validation_schema(version: "2025-09"), payloads)
          documentation = accepted(dialect, request.to_schema(version: "2025-09"), payloads)
          mismatches[[rule, dialect]] = (validation - documentation) + (documentation - validation) unless validation == documentation
        end
      end

      assert_empty results
    end

    def test_else_variant_negates_the_given_when_it_can_still_hold
      request = build_kind_request

      schema = request.to_schema(version: "2025-09")

      assert_equal({"type" => "object", "required" => %w[vat_id kind], "properties" => {"kind" => {"type" => "string", "const" => "company"}, "vat_id" => {"type" => "string"}}, "additionalProperties" => false}, schema["oneOf"][0])
      assert_equal({"type" => "object", "required" => [], "properties" => {"kind" => {"type" => "string"}}, "additionalProperties" => false, "not" => {"required" => %w[kind], "properties" => {"kind" => {"const" => "company"}}}}, schema["oneOf"][1])

      payloads = [{"kind" => "company", "vat_id" => "1"}, {"kind" => "company"}, {"kind" => "person"}, {"kind" => "person", "vat_id" => "1"}, {}]
      validation = request.to_validation_schema(version: "2025-09")

      assert_equal accepted(:draft2020_12, validation, payloads), accepted(:draft2020_12, schema, payloads)
    end

    def test_open_scopes_forbid_the_other_branch_properties
      request = Class.new(Verquest::Base) do
        schema_options additional_properties: true

        version "2025-09" do
          condition :card, document_as: :one_of do
            given { present :credit_card }
            then_apply { field :credit_card, type: :string, required: true }
            else_apply { field :invoice_email, type: :string }
          end
        end
      end

      schema = request.to_schema(version: "2025-09")

      assert_equal({"credit_card" => {"type" => "string"}, "invoice_email" => false}, schema["oneOf"][0]["properties"])
      assert_equal({"invoice_email" => {"type" => "string"}, "credit_card" => false}, schema["oneOf"][1]["properties"])
      payloads = [{"credit_card" => "4111"}, {"invoice_email" => "a@b.c"}, {"credit_card" => "4111", "invoice_email" => "a@b.c"}, {"other" => 1}, {}]

      assert_equal accepted(:draft2020_12, request.to_validation_schema(version: "2025-09"), payloads), accepted(:draft2020_12, schema, payloads)
    end

    def test_branch_documentation_without_document_as_is_ignored
      request = Class.new(Verquest::Base) do
        version "2025-09" do
          condition do
            given { present :credit_card }
            then_apply(title: "Card") { field :credit_card, type: :string, required: true }
          end
        end
      end

      refute request.to_schema(version: "2025-09").key?("oneOf")
      refute request.to_schema(version: "2025-09")["then"].key?("title")
    end

    def test_only_one_condition_can_be_documented_as_one_of
      error = assert_raises(ArgumentError) do
        Class.new(Verquest::Base) do
          version "2025-09" do
            field :kind, type: :string

            condition :card, document_as: :one_of do
              given { present :credit_card }
              then_apply { field :credit_card, type: :string, required: true }
            end

            condition :company do
              given { equals :kind, "company" }
              then_apply { field :vat_id, type: :string, required: true }
            end
          end
        end.to_schema(version: "2025-09")
      end

      assert_equal "A condition documented as one_of must be the only condition in its version", error.message
    end

    def test_document_as_is_only_allowed_in_a_version
      error = assert_raises(ArgumentError) do
        Class.new(Verquest::Base) do
          version "2025-09" do
            object :payment do
              condition document_as: :one_of do
                given { present :credit_card }
                then_apply { field :credit_card, type: :string, required: true }
              end
            end
          end
        end
      end

      assert_equal "document_as: :one_of can only be used on a condition in a version", error.message
    end

    def test_unknown_document_as_raises
      error = assert_raises(ArgumentError) do
        Class.new(Verquest::Base) do
          version("2025-09") { condition(document_as: :any_of) {} }
        end
      end

      assert_equal "document_as must be :one_of (got :any_of)", error.message
    end

    private

    def build_request(dialect = :openapi31)
      with_configuration(json_schema_version: dialect) do
        Class.new(Verquest::Base) do
          description "Price adjustment"

          version "2025-09" do
            field :effective_from, type: :string, required: true

            condition :pricing, document_as: :one_of do
              given { present :percentages }
              then_apply title: "Per-type percentages" do
                object :percentages, required: true, min_properties: 1 do
                  field :unit_types, type: :number, maximum: 9999.99
                end
              end
              else_apply title: "Shared percentage", description: "Use percentages instead", deprecated: true do
                field :percentage, type: :number, required: true, not: {"const" => 0}
                object :applies_to do
                  field :unit_types, type: :boolean, map: "/apply_to_unit_types"
                end
              end
            end
          end
        end
      end
    end

    def build_kind_request
      Class.new(Verquest::Base) do
        version "2025-09" do
          field :kind, type: :string

          condition :company, document_as: :one_of do
            given { equals :kind, "company" }
            then_apply { field :vat_id, type: :string, required: true }
          end
        end
      end
    end

    def build_rule_request(dialect, given_block)
      with_configuration(json_schema_version: dialect) do
        Class.new(Verquest::Base) do
          version "2025-09" do
            field :kind, type: :string
            field :age, type: :integer, minimum: 0
            field :note, type: :string

            condition :rule, document_as: :one_of do
              given(&given_block)
              then_apply { field :vat_id, type: :string, required: true }
              else_apply { field :reason, type: :string }
            end
          end
        end
      end
    end

    # Every combination of RULE_VALUES, leaving out the absent (nil) ones
    def rule_payloads
      values = RULE_VALUES.values
      values.first.product(*values.drop(1)).map do |combination|
        RULE_VALUES.keys.zip(combination).to_h.compact
      end
    end

    def accepted(dialect, schema, payloads = PAYLOADS)
      schemer = with_configuration(json_schema_version: dialect) { JSONSchemer.schema(schema, meta_schema: Verquest.configuration.json_schema_uri) }
      payloads.select { |payload| schemer.valid?(payload) }
    end
  end
end

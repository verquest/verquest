# frozen_string_literal: true

require "test_helper"

module Verquest
  module HelperMethods
    class ConditionalPropertiesTest < Minitest::Test
      def test_single_condition_is_inlined
        version = build_version(pricing_condition)

        expected = {
          "type" => "object",
          "required" => %w[effective_from],
          "properties" => {
            "effective_from" => {"type" => "string"},
            "percentages" => {"type" => "number"},
            "percentage" => {"type" => "number"}
          },
          "additionalProperties" => false,
          "if" => {"required" => %w[percentages]},
          "then" => {"required" => %w[percentages], "properties" => {"percentage" => false}},
          "else" => {"required" => %w[percentage], "properties" => {"percentages" => false}}
        }

        assert_equal expected, version.schema
        assert_equal expected, version.validation_schema
      end

      def test_several_conditions_use_all_of
        version = build_version(pricing_condition, contact_condition)

        expected_all_of = [pricing_condition.to_schema, contact_condition.to_schema]

        assert_equal expected_all_of, version.schema["allOf"]
        assert_equal %w[effective_from percentages percentage vat_id], version.schema["properties"].keys
        refute version.schema.key?("if")
      end

      def test_all_properties_and_mapping_include_branch_properties
        version = build_version(pricing_condition)

        assert_equal %w[effective_from percentages percentage], version.all_properties.keys
        assert_equal %w[effective_from], version.properties.keys
        assert_equal({"effective_from" => "effective_from", "percentages" => "percentages", "percentage" => "percentage"}, version.mapping)
      end

      def test_mapping_for_branch_property
        version = build_version(pricing_condition)

        assert_equal({"percentage" => "percentage"}, version.mapping_for(:percentage))
      end

      def test_all_properties_follows_later_declarations_until_prepared
        version = Version.new(name: "2025-09")
        version.add_condition(pricing_condition)
        before = version.all_properties.keys
        version.add(Properties::Field.new(name: :effective_from, type: :string))

        assert_equal %w[percentages percentage], before
        assert_equal %w[effective_from percentages percentage], version.all_properties.keys
      end

      def test_scope_without_conditions_is_unchanged
        version = build_version

        assert_equal version.properties, version.all_properties
        assert_empty version.schema.keys & %w[if then else allOf]
        assert_empty version.validation_schema.keys & %w[if then else allOf]
      end

      def test_branch_property_clashing_with_scope_property_raises
        condition = Conditions::Condition.new
        condition.open(:given).add_rule(Conditions::Rules::Present.new(%i[effective_from]))
        condition.open(:then).add(Properties::Field.new(name: :effective_from, type: :string))

        error = assert_raises(ArgumentError) { build_version(condition) }

        assert_equal "Property 'effective_from' is declared both outside and inside a condition", error.message
      end

      def test_branch_properties_clashing_across_conditions_raise
        other = Conditions::Condition.new
        other.open(:given).add_rule(Conditions::Rules::Present.new(%i[effective_from]))
        other.open(:then).add(Properties::Field.new(name: :percentage, type: :integer))

        error = assert_raises(ArgumentError) { build_version(pricing_condition, other) }

        assert_equal "Property 'percentage' is declared differently in several condition branches", error.message
      end

      def test_duplicate_condition_names_raise
        version = Version.new(name: "2025-09")
        version.add_condition(pricing_condition)
        version.add_condition(Conditions::Condition.new)

        error = assert_raises(ArgumentError) { version.add_condition(pricing_condition) }

        assert_equal "Condition 'pricing' is already defined", error.message
      end

      def test_raw_conditional_keywords_raise
        version = Version.new(name: "2025-09")
        version.schema_options["allOf"] = [{"required" => %w[a]}]
        version.add_condition(pricing_condition)

        error = assert_raises(ArgumentError) { version.prepare }

        assert_equal "Raw if, then, else or allOf schema options can not be combined with conditions", error.message
      end

      def test_invalid_condition_raises
        error = assert_raises(ArgumentError) { build_version(Conditions::Condition.new(name: :empty)) }

        assert_equal "Condition 'empty' needs a given block with at least one rule", error.message
      end

      def test_unknown_rule_names_raise
        condition = Conditions::Condition.new(name: :typo)
        condition.open(:given).add_rule(Conditions::Rules::Present.new(%i[efective_from]))
        condition.open(:then).add(Properties::Field.new(name: :note, type: :string))

        error = assert_raises(ArgumentError) { build_version(condition) }

        assert_equal "Condition 'typo' uses unknown properties: efective_from", error.message
      end

      def test_condition_in_combination_version_raises
        version = Version.new(name: "2025-09")
        version.add(Properties::OneOf.new)
        version.add_condition(pricing_condition)

        error = assert_raises(ArgumentError) { version.prepare }

        assert_equal "Conditions can not be declared next to a root-level one_of", error.message
      end

      private

      def build_version(*conditions)
        Version.new(name: "2025-09").tap do |version|
          version.add(Properties::Field.new(name: :effective_from, type: :string, required: true))
          conditions.each { |condition| version.add_condition(condition) }
          version.prepare
        end
      end

      def pricing_condition
        Conditions::Condition.new(name: :pricing).tap do |condition|
          condition.open(:given).add_rule(Conditions::Rules::Present.new(%i[percentages]))
          condition.open(:then).add(Properties::Field.new(name: :percentages, type: :number, required: true))
          condition.open(:else).add(Properties::Field.new(name: :percentage, type: :number, required: true))
        end
      end

      def contact_condition
        Conditions::Condition.new.tap do |condition|
          condition.open(:given).add_rule(Conditions::Rules::Present.new(%i[effective_from]))
          condition.open(:then).add(Properties::Field.new(name: :vat_id, type: :string))
        end
      end
    end
  end
end

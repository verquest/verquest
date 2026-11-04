# frozen_string_literal: true

require "test_helper"

module Verquest
  module Conditions
    class ConditionTest < Minitest::Test
      def test_to_schema_with_exclusive_branches
        condition = pricing_condition

        expected = {
          "if" => {"required" => %w[percentages]},
          "then" => {"required" => %w[percentages], "properties" => {"percentage" => false}},
          "else" => {"required" => %w[percentage], "properties" => {"percentages" => false}}
        }

        assert_equal expected, condition.to_schema
      end

      def test_name_properties_and_rule_property_names
        condition = pricing_condition

        assert_equal "pricing", condition.name
        assert_equal %w[percentages percentage], condition.properties.keys
        assert_equal %w[percentages], condition.rule_property_names
      end

      def test_generates_else_that_forbids_then_properties
        condition = Condition.new
        condition.open(:given).add_rule(Rules::Equals.new(:kind, "company"))
        condition.open(:then).add(Properties::Field.new(name: :vat_id, type: :string, required: true))

        expected = {
          "if" => {"required" => %w[kind], "properties" => {"kind" => {"const" => "company"}}},
          "then" => {"required" => %w[vat_id]},
          "else" => {"properties" => {"vat_id" => false}}
        }

        assert_equal expected, condition.to_schema
        assert_equal %w[kind], condition.rule_property_names
      end

      def test_generates_then_that_forbids_else_properties
        condition = Condition.new
        condition.open(:given).add_rule(Rules::Present.new(%i[legacy]))
        condition.open(:else).add(Properties::Field.new(name: :modern, type: :string))

        expected = {"if" => {"required" => %w[legacy]}, "then" => {"properties" => {"modern" => false}}}

        assert_equal expected, condition.to_schema
      end

      def test_identical_declarations_in_both_branches_are_allowed
        condition = Condition.new
        condition.open(:given).add_rule(Rules::Present.new(%i[a]))
        condition.open(:then).add(Properties::Field.new(name: :note, type: :string, required: true))
        condition.open(:else).add(Properties::Field.new(name: :note, type: :string))

        expected = {"if" => {"required" => %w[a]}, "then" => {"required" => %w[note]}}

        assert_equal expected, condition.to_schema
        assert_equal %w[note], condition.properties.keys
      end

      def test_different_declarations_in_both_branches_raise
        condition = Condition.new
        condition.open(:given).add_rule(Rules::Present.new(%i[a]))
        condition.open(:then).add(Properties::Field.new(name: :note, type: :string))
        condition.open(:else).add(Properties::Field.new(name: :note, type: :integer))

        error = assert_raises(ArgumentError) { condition.properties }

        assert_equal "Property 'note' is declared differently in several condition branches", error.message
      end

      def test_rule_property_names_include_branch_rules
        condition = Condition.new
        condition.open(:given).add_rule(Rules::Present.new(%i[a]))
        condition.open(:then).add_rule(Rules::Absent.new(%i[b]))
        condition.open(:else).add_rule(Rules::Present.new(%i[a c]))

        assert_equal %w[a b c], condition.rule_property_names
      end

      def test_validate_requires_given_rules
        condition = Condition.new(name: :pricing)
        condition.open(:then)

        error = assert_raises(ArgumentError) { condition.validate!([]) }

        assert_equal "Condition 'pricing' needs a given block with at least one rule", error.message
      end

      def test_validate_requires_a_branch
        condition = Condition.new
        condition.open(:given).add_rule(Rules::Present.new(%i[a]))

        error = assert_raises(ArgumentError) { condition.validate!([]) }

        assert_equal "Condition needs a then_apply or else_apply block", error.message
      end

      def test_validate_rejects_unknown_property_names
        error = assert_raises(ArgumentError) { pricing_condition.validate!(%w[percentage]) }

        assert_equal "Condition 'pricing' uses unknown properties: percentages", error.message
      end

      def test_validate_passes
        assert_nil pricing_condition.validate!(%w[percentages percentage])
      end

      def test_parts_can_be_opened_only_once
        condition = Condition.new(name: :pricing)
        condition.open(:given)

        error = assert_raises(ArgumentError) { condition.open(:given) }

        assert_equal "given can be declared only once in Condition 'pricing'", error.message
      end

      def test_properties_must_be_declared_in_a_branch
        error = assert_raises(ArgumentError) { Condition.new.add(Properties::Field.new(name: :a, type: :string)) }

        assert_equal "Properties of Condition must be declared inside then_apply or else_apply", error.message
      end

      private

      def pricing_condition
        Condition.new(name: :pricing).tap do |condition|
          condition.open(:given).add_rule(Rules::Present.new(%i[percentages]))
          condition.open(:then).add(Properties::Field.new(name: :percentages, type: :number, required: true))
          condition.open(:else).add(Properties::Field.new(name: :percentage, type: :number, required: true))
        end
      end
    end
  end
end

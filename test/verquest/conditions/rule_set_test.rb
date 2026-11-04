# frozen_string_literal: true

require "test_helper"

module Verquest
  module Conditions
    class RuleSetTest < Minitest::Test
      def test_merges_rule_fragments
        rule_set = build_rule_set(
          Rules::Present.new(%i[a]),
          Rules::Equals.new(:kind, "x"),
          Rules::Satisfies.new(:kind, {minLength: 1}),
          Rules::Present.new(%i[a b])
        )

        expected = {"required" => %w[a b], "properties" => {"kind" => {"const" => "x", "minLength" => 1}}}

        assert_equal expected, rule_set.to_schema
        assert_equal %w[a kind b], rule_set.property_names
      end

      def test_in_given_adds_required_without_duplicates
        rule_set = build_rule_set(Rules::Present.new(%i[kind]), Rules::Equals.new(:kind, "x"))

        assert_equal({"required" => %w[kind], "properties" => {"kind" => {"const" => "x"}}}, rule_set.to_schema(in_given: true))
      end

      def test_conflicting_rules_raise
        rule_set = build_rule_set(Rules::Equals.new(:kind, "a"), Rules::Equals.new(:kind, "b"))

        error = assert_raises(ArgumentError) { rule_set.to_schema }

        assert_equal "Conflicting rules for 'const': \"a\" and \"b\"", error.message
      end

      def test_absent_and_value_rule_conflict
        rule_set = build_rule_set(Rules::Absent.new(%i[kind]), Rules::Equals.new(:kind, "a"))

        error = assert_raises(ArgumentError) { rule_set.to_schema }

        assert_match(/\AConflicting rules for 'kind': false and \{/, error.message)
      end

      def test_equal_values_are_kept
        rule_set = build_rule_set(Rules::Absent.new(%i[a]), Rules::Absent.new(%i[a b]))

        assert_equal({"properties" => {"a" => false, "b" => false}}, rule_set.to_schema)
      end

      def test_empty_rule_set
        assert_empty RuleSet.new.to_schema
      end

      def test_properties_are_not_allowed
        error = assert_raises(ArgumentError) { RuleSet.new.add(Properties::Field.new(name: :a, type: :string)) }

        assert_equal "Properties can not be declared inside given, any or none", error.message
      end

      def test_any
        any = build_rule_set(Rules::Present.new(%i[a]), Rules::Equals.new(:kind, "x"), rule_set: Rules::Any.new)

        assert_equal %w[a kind], any.property_names
        assert_equal({"anyOf" => [{"required" => %w[a]}, {"properties" => {"kind" => {"const" => "x"}}}]}, any.to_schema)
        assert_equal(
          {"anyOf" => [{"required" => %w[a]}, {"required" => %w[kind], "properties" => {"kind" => {"const" => "x"}}}]},
          any.to_schema(in_given: true)
        )
      end

      def test_none
        none = build_rule_set(Rules::Present.new(%i[a]), Rules::Present.new(%i[b]), rule_set: Rules::None.new)

        assert_equal %w[a b], none.property_names
        assert_equal({"not" => {"anyOf" => [{"required" => %w[a]}, {"required" => %w[b]}]}}, none.to_schema)
      end

      def test_nested_any_merges_with_other_rules
        any = build_rule_set(Rules::Present.new(%i[a]), Rules::Present.new(%i[b]), rule_set: Rules::Any.new)
        rule_set = build_rule_set(Rules::Absent.new(%i[c]), any)

        expected = {"properties" => {"c" => false}, "anyOf" => [{"required" => %w[a]}, {"required" => %w[b]}]}

        assert_equal expected, rule_set.to_schema
        assert_equal %w[c a b], rule_set.property_names
      end

      def test_empty_any_raises
        error = assert_raises(ArgumentError) { Rules::Any.new.to_schema }

        assert_equal "any and none need at least one rule", error.message
      end

      def test_empty_none_raises
        error = assert_raises(ArgumentError) { Rules::None.new.to_schema(in_given: true) }

        assert_equal "any and none need at least one rule", error.message
      end

      private

      def build_rule_set(*rules, rule_set: RuleSet.new)
        rules.each { |rule| rule_set.add_rule(rule) }
        rule_set
      end
    end
  end
end

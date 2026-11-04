# frozen_string_literal: true

require "test_helper"

module Verquest
  module Conditions
    class RulesTest < Minitest::Test
      def test_present
        rule = Rules::Present.new(%i[a b])

        assert_equal %w[a b], rule.property_names
        assert_equal({"required" => %w[a b]}, rule.to_schema(in_given: false))
        assert_equal({"required" => %w[a b]}, rule.to_schema(in_given: true))
      end

      def test_absent
        rule = Rules::Absent.new(%i[a b])

        assert_equal %w[a b], rule.property_names
        assert_equal({"properties" => {"a" => false, "b" => false}}, rule.to_schema(in_given: false))
        assert_equal({"properties" => {"a" => false, "b" => false}}, rule.to_schema(in_given: true))
      end

      def test_equals
        rule = Rules::Equals.new(:kind, "company")

        assert_equal %w[kind], rule.property_names
        assert_equal({"properties" => {"kind" => {"const" => "company"}}}, rule.to_schema(in_given: false))
        assert_equal({"required" => %w[kind], "properties" => {"kind" => {"const" => "company"}}}, rule.to_schema(in_given: true))
      end

      def test_value_in
        rule = Rules::ValueIn.new(:kind, %w[a b])

        assert_equal %w[kind], rule.property_names
        assert_equal({"properties" => {"kind" => {"enum" => %w[a b]}}}, rule.to_schema(in_given: false))
        assert_equal({"required" => %w[kind], "properties" => {"kind" => {"enum" => %w[a b]}}}, rule.to_schema(in_given: true))
      end

      def test_satisfies
        rule = Rules::Satisfies.new(:age, {minimum: 18, exclusiveMaximum: 100})

        assert_equal %w[age], rule.property_names
        assert_equal({"properties" => {"age" => {"minimum" => 18, "exclusiveMaximum" => 100}}}, rule.to_schema(in_given: false))
        assert_equal({"required" => %w[age], "properties" => {"age" => {"minimum" => 18, "exclusiveMaximum" => 100}}}, rule.to_schema(in_given: true))
      end
    end
  end
end

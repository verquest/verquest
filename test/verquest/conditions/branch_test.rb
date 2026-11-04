# frozen_string_literal: true

require "test_helper"

module Verquest
  module Conditions
    class BranchTest < Minitest::Test
      def test_required_properties_and_rules
        branch = Branch.new
        branch.add(Properties::Field.new(name: :percentage, type: :number, required: true))
        branch.add(Properties::Field.new(name: :note, type: :string))
        branch.add_rule(Rules::Present.new(%i[note]))
        branch.add_rule(Rules::Absent.new(%i[legacy]))

        expected = {"required" => %w[percentage note], "properties" => {"legacy" => false}}

        assert_equal expected, branch.to_schema
        assert_equal %w[percentage note], branch.properties.keys
        assert_equal %w[note legacy], branch.rule_property_names
      end

      def test_forbidden_names
        branch = Branch.new
        branch.add_rule(Rules::Equals.new(:kind, "a"))

        expected = {"properties" => {"kind" => {"const" => "a"}, "percentage" => false, "applies_to" => false}}

        assert_equal expected, branch.to_schema(forbidden: %w[percentage applies_to])
      end

      def test_requiring_a_forbidden_name_raises
        branch = Branch.new
        branch.add_rule(Rules::Present.new(%i[z]))

        error = assert_raises(ArgumentError) { branch.to_schema(forbidden: %w[z]) }

        assert_equal "Branch requires z, which only the other branch declares", error.message
      end

      def test_dependent_required
        branch = Branch.new
        branch.add(Properties::Field.new(name: :billing_address, type: :string, required: %i[credit_card]))

        assert_equal({"dependentRequired" => {"billing_address" => %w[credit_card]}}, branch.to_schema)
      end

      def test_empty_branch
        assert_empty Branch.new.to_schema
      end

      def test_one_of_is_not_allowed
        error = assert_raises(ArgumentError) { Branch.new.add(Properties::OneOf.new(name: :pet)) }

        assert_equal "one_of can not be declared inside a condition", error.message
      end
    end
  end
end

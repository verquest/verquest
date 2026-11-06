# frozen_string_literal: true

module Verquest
  module Conditions
    # The rules of one block, combined with AND
    #
    # Used as the DSL scope of `given`, so rule methods add to it and property
    # declarations raise. {Rules::Any} and {Rules::None} build on it.
    #
    # @example
    #   rule_set = RuleSet.new
    #   rule_set.add_rule(Rules::Present.new(%i[percentages]))
    #   rule_set.to_schema(in_given: true)
    #   # => {"required" => ["percentages"]}
    class RuleSet
      # @!attribute [r] rules
      #   @return [Array<#to_schema>] The rules in declaration order
      attr_reader :rules

      # Initialize an empty rule set
      def initialize
        @rules = []
      end

      # Add a rule
      #
      # @param rule [#to_schema, #property_names] The rule to add
      # @return [Array] The rules
      def add_rule(rule)
        rules << rule
      end

      # Rejects property declarations, which are only allowed in branches
      #
      # @param _property [Verquest::Properties::Base] The property that was declared
      # @raise [ArgumentError] Always
      def add(_property)
        raise ArgumentError, "Properties can not be declared inside given, any or none"
      end

      # Returns the names of the properties the rules use
      #
      # @return [Array<String>] The property names, without duplicates
      def property_names
        rules.flat_map(&:property_names).uniq
      end

      # Builds the merged schema fragment of all rules
      #
      # @param in_given [Boolean] Whether the rules are used inside `given`
      # @return [Hash] The schema fragment
      # @raise [ArgumentError] If two rules conflict
      def to_schema(in_given: false)
        FragmentMerge.call(rules.map { |rule| rule.to_schema(in_given:) })
      end

      # Checks whether every payload of the variant matches all the rules
      #
      # @param variant [Hash] The documented oneOf variant
      # @return [Boolean] true when every rule holds in the variant
      def holds_in?(variant)
        rules.all? { |rule| rule.holds_in?(variant) }
      end

      # Checks whether no payload of the variant matches all the rules
      #
      # @param variant [Hash] The documented oneOf variant
      # @return [Boolean] true when a rule fails in the variant
      def fails_in?(variant)
        rules.any? { |rule| rule.fails_in?(variant) }
      end
    end
  end
end

# frozen_string_literal: true

module Verquest
  module Conditions
    module Rules
      # Base class for rules whose nested rules are alternatives
      #
      # Each rule inside the block becomes one `anyOf` entry, so an empty block
      # would produce an invalid (`anyOf: []`) or meaningless schema and raises.
      #
      # @abstract Subclass and implement `#to_schema(in_given:)` with {#alternatives}
      class Alternatives < RuleSet
        private

        # Builds one schema fragment per nested rule
        #
        # @param in_given [Boolean] Whether the rule is used inside `given`
        # @return [Array<Hash>] The fragments, one per alternative
        # @raise [ArgumentError] If the block declared no rules
        def alternatives(in_given:)
          raise ArgumentError, "any and none need at least one rule" if rules.empty?

          rules.map { |rule| rule.to_schema(in_given:) }
        end
      end
    end
  end
end

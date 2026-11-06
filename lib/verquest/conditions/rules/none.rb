# frozen_string_literal: true

module Verquest
  module Conditions
    module Rules
      # Requires none of its rules to hold
      #
      # @example
      #   none = None.new
      #   none.add_rule(Present.new(%i[email]))
      #   none.to_schema(in_given: false)
      #   # => {"not" => {"anyOf" => [{"required" => ["email"]}]}}
      class None < Alternatives
        # Builds the schema fragment that negates the alternatives
        #
        # @param in_given [Boolean] Whether the rule is used inside `given`
        # @return [Hash] The schema fragment
        def to_schema(in_given: false)
          {"not" => {"anyOf" => alternatives(in_given:)}}
        end

        # Checks whether no payload of the variant matches any of the rules
        #
        # @param variant [Hash] The documented oneOf variant
        # @return [Boolean] true when every rule fails in the variant
        def holds_in?(variant)
          rules.all? { |rule| rule.fails_in?(variant) }
        end

        # Checks whether every payload of the variant matches one of the rules
        #
        # @param variant [Hash] The documented oneOf variant
        # @return [Boolean] true when a rule holds in the variant
        def fails_in?(variant)
          rules.any? { |rule| rule.holds_in?(variant) }
        end
      end
    end
  end
end

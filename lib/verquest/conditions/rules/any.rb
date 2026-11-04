# frozen_string_literal: true

module Verquest
  module Conditions
    module Rules
      # Requires at least one of its rules to hold
      #
      # Each rule inside the block is one alternative.
      #
      # @example
      #   any = Any.new
      #   any.add_rule(Present.new(%i[email]))
      #   any.add_rule(Present.new(%i[phone]))
      #   any.to_schema(in_given: false)
      #   # => {"anyOf" => [{"required" => ["email"]}, {"required" => ["phone"]}]}
      class Any < Alternatives
        # Builds the schema fragment with one `anyOf` entry per rule
        #
        # @param in_given [Boolean] Whether the rule is used inside `given`
        # @return [Hash] The schema fragment
        def to_schema(in_given: false)
          {"anyOf" => alternatives(in_given:)}
        end
      end
    end
  end
end

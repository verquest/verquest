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
      end
    end
  end
end

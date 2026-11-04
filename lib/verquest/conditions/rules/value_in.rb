# frozen_string_literal: true

module Verquest
  module Conditions
    module Rules
      # Requires a property to hold one of several values
      #
      # @example
      #   ValueIn.new(:kind, %w[a b]).to_schema(in_given: false)
      #   # => {"properties" => {"kind" => {"enum" => ["a", "b"]}}}
      class ValueIn < PropertyRule
        # Initialize a new ValueIn rule
        #
        # @param name [Symbol, String] The property the rule constrains
        # @param values [Array] The values the property may hold
        def initialize(name, values)
          super(name, {"enum" => values})
        end
      end
    end
  end
end

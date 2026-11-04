# frozen_string_literal: true

module Verquest
  module Conditions
    module Rules
      # Requires a property to hold one value
      #
      # @example
      #   Equals.new(:kind, "company").to_schema(in_given: false)
      #   # => {"properties" => {"kind" => {"const" => "company"}}}
      class Equals < PropertyRule
        # Initialize a new Equals rule
        #
        # @param name [Symbol, String] The property the rule constrains
        # @param value [Object] The value the property must hold
        def initialize(name, value)
          super(name, {"const" => value})
        end
      end
    end
  end
end

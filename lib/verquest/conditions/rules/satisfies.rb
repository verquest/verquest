# frozen_string_literal: true

module Verquest
  module Conditions
    module Rules
      # Requires a property to match arbitrary schema options
      #
      # @example
      #   Satisfies.new(:age, {minimum: 18}).to_schema(in_given: false)
      #   # => {"properties" => {"age" => {"minimum" => 18}}}
      class Satisfies < PropertyRule
        # Initialize a new Satisfies rule
        #
        # @param name [Symbol, String] The property the rule constrains
        # @param schema_options [Hash] Schema options (already camelized) the property value must match
        def initialize(name, schema_options)
          super(name, schema_options.transform_keys(&:to_s))
        end
      end
    end
  end
end

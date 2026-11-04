# frozen_string_literal: true

module Verquest
  module Conditions
    module Rules
      # Base class for rules that constrain the value of a single property
      #
      # Inside `given`, the rule also requires the property. Without that,
      # `if: {properties: {kind: {const: "x"}}}` would match when `kind` is missing.
      #
      # @abstract Subclass and pass the property schema to {#initialize}
      class PropertyRule
        # Initialize a new property rule
        #
        # @param name [Symbol, String] The property the rule constrains
        # @param schema [Hash] The schema the property value must match
        def initialize(name, schema)
          @name = name.to_s
          @schema = schema
        end

        # Returns the names of the properties the rule uses
        #
        # @return [Array<String>] The constrained property name
        def property_names
          [name]
        end

        # Builds the schema fragment for this rule
        #
        # @param in_given [Boolean] Whether the rule is used inside `given`, which also requires the property
        # @return [Hash] The schema fragment
        def to_schema(in_given: false)
          fragment = {"properties" => {name => schema}}
          in_given ? {"required" => [name]}.merge(fragment) : fragment
        end

        private

        # @!attribute [r] name
        #   @return [String] The constrained property name
        # @!attribute [r] schema
        #   @return [Hash] The schema the property value must match
        attr_reader :name, :schema
      end
    end
  end
end

# frozen_string_literal: true

module Verquest
  module Properties
    # The Const class represents a constant property with a fixed value in a JSON schema.
    # It's used for properties that must have a specific, immutable value.
    #
    # @example
    #   const = Const.new(name: "type", value: "user")
    class Const < Base
      # Initialize a new constant property
      #
      # @param name [String, Symbol] The name of the constant property
      # @param value [Object] The fixed value of the constant (can be any scalar value)
      # @param map [Object, nil] Optional mapping information
      # @param required [Boolean, Array<Symbol>] Whether this property is required, or array of dependency names (can be overridden by custom type)
      # @param schema_options [Hash] Additional JSON schema options for this property
      def initialize(name:, value:, map: nil, required: false, **schema_options)
        @name = name.to_s
        @value = value
        @map = map
        @required = required
        @schema_options = schema_options&.transform_keys(&:to_s)
      end

      # Generate JSON schema definition for this constant
      #
      # @return [Hash] The schema definition for this constant
      def to_schema
        {
          name => {
            "const" => value
          }.merge(schema_options)
        }
      end

      # Create mapping for this const property
      #
      # @param key_prefix [Array<String>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String, nil] The version to create mapping for
      # @return [void]
      def mapping(key_prefix:, value_prefix:, mapping:, version: nil)
        mapping[(key_prefix + [name]).join("/")] = mapping_value_key(value_prefix:)
      end

      private

      attr_reader :value, :schema_options
    end
  end
end

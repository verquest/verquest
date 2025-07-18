# frozen_string_literal: true

module Verquest
  module Properties
    # The Enum class represents a enum property with a list of possible values in a JSON schema.
    #
    # @example
    #   enum = Enum.new(name: "type", values: ["member", "admin"])
    class Enum < Base
      # Initialize a new Enum property
      #
      # @param name [String, Symbol] The name of the property
      # @param values [Array] The enum values for this property
      # @param required [Boolean, Array<Symbol>] Whether this property is required, or array of dependency names
      # @param nullable [Boolean] Whether this property can be null
      # @param map [String, nil] The mapping path for this property
      # @param schema_options [Hash] Additional JSON schema options for this property
      # @raise [ArgumentError] If attempting to map an enum to root without a name
      # @raise [ArgumentError] If values is empty
      # @raise [ArgumentError] If values are not unique
      # @raise [ArgumentError] If only one value is provided (should use const instead)
      def initialize(name:, values:, required: false, nullable: false, map: nil, **schema_options)
        raise ArgumentError, "You can not map enums to the root without a name" if map == "/"
        raise ArgumentError, "Values must not be empty" if values.empty?
        raise ArgumentError, "Values must be unique" if values.uniq.length != values.length
        raise ArgumentError, "Use const for a single value" if values.length == 1

        @name = name.to_s
        @values = values
        @required = required
        @nullable = nullable
        @map = map
        @schema_options = schema_options&.transform_keys(&:to_s)

        if nullable && !values.include?("null")
          values << "null"
        end
      end

      # Generate JSON schema definition for this enum
      #
      # @return [Hash] The schema definition for this enum
      def to_schema
        {
          name => {"enum" => values}.merge(schema_options)
        }
      end

      # Create mapping for this enum property
      #
      # @param key_prefix [Array<Symbol>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String, nil] The version to create mapping for
      # @return [Hash] The updated mapping hash
      def mapping(key_prefix:, value_prefix:, mapping:, version: nil)
        mapping[(key_prefix + [name]).join("/")] = mapping_value_key(value_prefix:)
      end

      private

      attr_reader :values, :schema_options
    end
  end
end

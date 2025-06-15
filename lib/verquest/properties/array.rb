# frozen_string_literal: true

module Verquest
  module Properties
    # Array property type for schema generation and mapping
    #
    # Represents an array data structure in the schema with specified item type.
    # Used to define arrays of scalar types (string, number, integer, boolean).
    #
    # @example Define an array of strings
    #   array = Verquest::Properties::Array.new(
    #     name: :tags,
    #     type: :string,
    #     required: true
    #   )
    class Array < Base
      # Initialize a new Array property
      #
      # @param name [Symbol] The name of the property
      # @param type [Symbol] The type of items in the array
      # @param map [String, nil] The mapping path for this property (nil for no explicit mapping)
      # @param required [Boolean] Whether this property is required
      # @param schema_options [Hash] Additional JSON schema options for this property
      # @raise [ArgumentError] If attempting to map an array to the root
      def initialize(name:, type:, map: nil, required: false, **schema_options)
        raise ArgumentError, "You can not map array to the root" if map == "/"

        @name = name
        @type = type
        @map = map
        @required = required
        @schema_options = schema_options
      end

      # Generate JSON schema definition for this array property
      #
      # @return [Hash] The schema definition for this array property
      def to_schema
        {
          name => {
            type: :array,
            items: {type: type}
          }.merge(schema_options)
        }
      end

      # Create mapping for this array property
      #
      # @param key_prefix [Array<Symbol>] Prefix for the source key
      # @param value_prefix [Array<Symbol>] Prefix for the target value
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String, nil] The version to create mapping for, defaults to configuration setting
      # @return [Hash] The updated mapping hash
      def mapping(key_prefix:, value_prefix:, mapping:, version: nil)
        mapping[(key_prefix + [name]).join(".")] = mapping_value_key(value_prefix:)
      end

      private

      attr_reader :type, :schema_options
    end
  end
end

# frozen_string_literal: true

module Verquest
  module Properties
    # Field property type for basic scalar values
    #
    # Represents simple scalar types (string, number, integer, boolean) in the schema.
    # Used for defining basic data fields without nesting.
    #
    # @example Define a required string field
    #   field = Verquest::Properties::Field.new(
    #     name: :email,
    #     type: :string,
    #     required: true,
    #     format: "email"
    #   )
    class Field < Base
      # List of allowed field types
      # @return [Array<Symbol>]
      ALLOWED_TYPES = %w[string number integer boolean].freeze

      # Initialize a new Field property
      #
      # @param name [String, Symbol] The name of the property
      # @param type [String, Symbol] The data type for this field, must be one of ALLOWED_TYPES
      # @param required [Boolean] Whether this property is required
      # @param map [String, nil] The mapping path for this property
      # @param schema_options [Hash] Additional JSON schema options for this property
      # @raise [ArgumentError] If type is not one of the allowed types
      # @raise [ArgumentError] If attempting to map a field to root without a name
      def initialize(name:, type:, required: false, map: nil, **schema_options)
        raise ArgumentError, "Type must be one of #{ALLOWED_TYPES.join(", ")}" unless ALLOWED_TYPES.include?(type.to_s)
        raise ArgumentError, "You can not map fields to the root without a name" if map == "/"

        @name = name.to_s
        @type = type.to_s
        @required = required
        @map = map
        @schema_options = schema_options&.transform_keys(&:to_s)
      end

      # Generate JSON schema definition for this field
      #
      # @return [Hash] The schema definition for this field
      def to_schema
        {name => {"type" => type}.merge(schema_options)}
      end

      # Create mapping for this field property
      #
      # @param key_prefix [Array<Symbol>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String, nil] The version to create mapping for
      # @return [Hash] The updated mapping hash
      def mapping(key_prefix:, value_prefix:, mapping:, version: nil)
        mapping[(key_prefix + [name]).join(".")] = mapping_value_key(value_prefix:)
      end

      private

      attr_reader :type, :schema_options
    end
  end
end

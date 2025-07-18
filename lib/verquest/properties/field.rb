# frozen_string_literal: true

module Verquest
  module Properties
    # Field property type for basic scalar values
    #
    # Represents simple scalar types (string, number, integer, boolean) in the schema.
    # Used for defining basic data fields without nesting.
    # Supports both default types and custom field types defined in the configuration.
    #
    # @example Define a required string field
    #   field = Verquest::Properties::Field.new(
    #     name: :email,
    #     type: :string,
    #     required: true,
    #     format: "email"
    #   )
    class Field < Base
      # List of default field types
      # @return [Array<Symbol>]
      DEFAULT_TYPES = %w[string number integer boolean].freeze

      # Initialize a new Field property
      #
      # @param name [String, Symbol] The name of the property
      # @param type [String, Symbol] The data type for this field, can be a default type or a custom field type
      # @param required [Boolean, Array<Symbol>] Whether this property is required, or array of dependency names (can be overridden by custom type)
      # @param nullable [Boolean] Whether this property can be null
      # @param map [String, nil] The mapping path for this property
      # @param schema_options [Hash] Additional JSON schema options for this property (merged with custom type options)
      # @raise [ArgumentError] If type is not one of the allowed types (default or custom)
      # @raise [ArgumentError] If attempting to map a field to root without a name
      def initialize(name:, type:, required: false, nullable: false, map: nil, **schema_options)
        raise ArgumentError, "Type must be one of #{allowed_types.join(", ")}" unless allowed_types.include?(type.to_s)
        raise ArgumentError, "You can not map fields to the root without a name" if map == "/"

        if (custom_type = Verquest.configuration.custom_field_types[type.to_sym])
          @type = custom_type[:type].to_s
          @required = custom_type.key?(:required) ? custom_type[:required] : required
          @schema_options = if custom_type.key?(:schema_options)
            custom_type[:schema_options].merge(schema_options).transform_keys(&:to_s)
          else
            schema_options.transform_keys(&:to_s)
          end
        else
          @type = type.to_s
          @required = required
          @schema_options = schema_options&.transform_keys(&:to_s)
        end

        @name = name.to_s
        @nullable = nullable
        @map = map

        if nullable
          @type = [@type, "null"]
        end
      end

      # Generate JSON schema definition for this field
      #
      # @return [Hash] The schema definition for this field
      def to_schema
        {
          name => {"type" => type}.merge(schema_options)
        }
      end

      # Create mapping for this field property
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

      attr_reader :type, :schema_options

      # Gets the list of allowed field types, including both default and custom types
      #
      # @return [Array<String>] Array of allowed field type names
      def allowed_types
        DEFAULT_TYPES + Verquest.configuration.custom_field_types.keys.map(&:to_s)
      end
    end
  end
end

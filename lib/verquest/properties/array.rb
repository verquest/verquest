# frozen_string_literal: true

module Verquest
  module Properties
    # Array property type for schema generation and mapping
    #
    # Represents an array data structure in the schema with specified item type.
    # Used to define arrays of scalar types (string, number, integer, boolean).
    # Supports both default item types and custom field types defined in the configuration.
    #
    # @example Define an array of strings
    #   array = Verquest::Properties::Array.new(
    #     name: :tags,
    #     type: :string,
    #     required: true
    #   )
    class Array < Base
      # @return [Boolean] In query requests, whether items are sent as repeated keys (true) or comma-separated (false)
      attr_reader :explode

      # Initialize a new Array property
      #
      # @param name [String, Symbol] The name of the property
      # @param type [String, Symbol] The type of items in the array, can be a default type or a custom field type
      # @param map [String, nil] The mapping path for this property (nil for no explicit mapping)
      # @param required [Boolean, Array<Symbol>] Whether this property is required, or array of dependency names
      # @param nullable [Boolean] Whether this property can be null
      # @param explode [Boolean, nil] In query requests, whether items are sent as repeated keys (true) or comma-separated (false); nil uses the configuration
      # @param item_schema_options [Hash] Additional JSON schema options for the array items (merged with custom type options)
      # @param schema_options [Hash] Additional JSON schema options for the array property itself
      # @raise [ArgumentError] If type is not one of the allowed types (default or custom)
      # @raise [ArgumentError] If attempting to map an array to the root
      def initialize(name:, type:, map: nil, required: false, nullable: false, explode: nil, item_schema_options: {}, **schema_options)
        raise ArgumentError, "Type must be one of #{allowed_types.join(", ")}" unless allowed_types.include?(type.to_s)
        raise ArgumentError, "You can not map array to the root" if map == "/"

        if (custom_type = Verquest.configuration.custom_field_types[type.to_sym])
          @item_type = custom_type[:type].to_s
          @item_schema_options = if custom_type.key?(:schema_options)
            custom_type[:schema_options].merge(item_schema_options).transform_keys(&:to_s)
          else
            item_schema_options.transform_keys(&:to_s)
          end
        else
          @item_type = type.to_s
          @item_schema_options = item_schema_options.transform_keys(&:to_s)
        end

        @name = name.to_s
        @map = map
        @required = required
        @nullable = nullable
        @explode = explode.nil? ? Verquest.configuration.query_array_explode : explode
        @schema_options = schema_options&.transform_keys(&:to_s)

        @type = if nullable
          %w[array null]
        else
          "array"
        end
      end

      # Generate JSON schema definition for this array property
      #
      # @return [Hash] The schema definition for this array property
      def to_schema
        {
          name => {
            "type" => type,
            "items" => {"type" => item_type}.merge(item_schema_options)
          }.merge(schema_options)
        }
      end

      # Create mapping for this array property
      #
      # @param key_prefix [Array<String>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String, nil] The version to create mapping for
      # @return [void]
      def mapping(key_prefix:, value_prefix:, mapping:, version: nil)
        mapping[(key_prefix + [name]).join("/")] = mapping_value_key(value_prefix:)
      end

      # Returns this array's explode value and parameter examples
      #
      # @param prefix [Array<String>] Path of the parent property
      # @param version [String] The version to resolve references with
      # @return [Hash{Array<String> => Hash}] The options of this array, by path
      def query_options(prefix:, version:)
        {prefix + [name] => {explode:, examples: parameter_examples}.compact}
      end

      private

      attr_reader :type, :item_type, :schema_options, :item_schema_options

      # Gets the list of allowed item types, including both default and custom types
      #
      # @return [Array<String>] Array of allowed item type names
      def allowed_types
        Verquest::Properties::Field::DEFAULT_TYPES + Verquest.configuration.custom_field_types.keys.map(&:to_s)
      end
    end
  end
end

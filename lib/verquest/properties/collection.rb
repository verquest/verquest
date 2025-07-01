# frozen_string_literal: true

module Verquest
  module Properties
    # Collection property type for arrays of objects
    #
    # Represents an array of complex objects in the schema.
    # Used for defining collections of structured data objects.
    #
    # @example Define a collection of items with inline properties
    #   products = Verquest::Properties::Collection.new(name: :products)
    #   products.add(Verquest::Properties::Field.new(name: :id, type: :string, required: true))
    #   products.add(Verquest::Properties::Field.new(name: :name, type: :string))
    #
    # @example Define a collection referencing an existing schema
    #   products = Verquest::Properties::Collection.new(
    #     name: :products,
    #     item: ProductRequest
    #   )
    class Collection < Base
      # Initialize a new Collection property
      #
      # @param name [String, Symbol] The name of the property
      # @param item [Verquest::Base, nil] Optional reference to an external schema class
      # @param required [Boolean] Whether this property is required
      # @param nullable [Boolean] Whether this property can be null
      # @param map [String, nil] The mapping path for this property
      # @param schema_options [Hash] Additional JSON schema options for this property
      # @raise [ArgumentError] If attempting to map a collection to the root
      def initialize(name:, item: nil, required: false, nullable: false, map: nil, **schema_options)
        raise ArgumentError, "You can not map collection to the root" if map == "/"

        @properties = {}

        @name = name.to_s
        @item = item
        @required = required
        @nullable = nullable
        @map = map
        @schema_options = schema_options&.transform_keys(&:to_s)

        @type = if nullable
          %w[array null]
        else
          "array"
        end
      end

      # Add a child property to this collection's item definition
      #
      # @param property [Verquest::Properties::Base] The property to add to the collection items
      # @return [Verquest::Properties::Base] The added property
      def add(property)
        properties[property.name] = property
      end

      # Check if this collection references an external item schema
      #
      # @return [Boolean] True if the collection uses an external reference
      def has_item?
        !item.nil?
      end

      # Generate JSON schema definition for this collection property
      #
      # @return [Hash] The schema definition for this collection property
      def to_schema
        if has_item?
          {
            name => {
              "type" => type,
              "items" => {
                "$ref" => item.to_ref
              }
            }.merge(schema_options)
          }
        else
          {
            name => {
              "type" => type,
              "items" => {
                "type" => "object",
                "required" => properties.values.select(&:required).map(&:name),
                "properties" => properties.transform_values { |property| property.to_schema[property.name] },
                "additionalProperties" => Verquest.configuration.default_additional_properties
              }
            }.merge(schema_options)
          }
        end
      end

      # Generate validation schema for this collection property
      #
      # @param version [String, nil] The version to generate validation schema for
      # @return [Hash] The validation schema for this collection property
      def to_validation_schema(version: nil)
        if has_item?
          {
            name => {
              "type" => type,
              "items" => item.to_validation_schema(version: version)
            }.merge(schema_options)
          }
        else
          {
            name => {
              "type" => type,
              "items" => {
                "type" => "object",
                "required" => properties.values.select(&:required).map(&:name),
                "properties" => properties.transform_values { |property| property.to_validation_schema(version: version)[property.name] },
                "additionalProperties" => Verquest.configuration.default_additional_properties
              }
            }.merge(schema_options)
          }
        end
      end

      # Create mapping for this collection property and all its children
      #
      # This method handles two different scenarios:
      # 1. When the collection references an external item schema (`has_item?` returns true)
      #    - Creates mappings by transforming keys from the referenced item schema
      #    - Adds array notation ([]) to indicate this is a collection
      #    - Prefixes all keys and values with the appropriate paths
      #
      # 2. When the collection has inline item properties
      #    - Creates mappings for each property in the collection items
      #    - Each property gets mapped with array notation and appropriate prefixes
      #
      # @param key_prefix [Array<String>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String, nil] The version to create mapping for
      # @return [Hash] The updated mapping hash
      def mapping(key_prefix:, value_prefix:, mapping:, version:)
        if has_item?
          value_key_prefix = mapping_value_key(value_prefix: value_prefix, collection: true)

          reference_mapping = item.mapping(version:).dup
          reference_mapping.transform_keys! { "#{(key_prefix + [name]).join(".")}[].#{_1}" }
          reference_mapping.transform_values! { "#{value_key_prefix}.#{_1}" }

          mapping.merge!(reference_mapping)
        else
          properties.values.each do |property|
            property.mapping(key_prefix: key_prefix + ["#{name}[]"], value_prefix: mapping_value_prefix(value_prefix: value_prefix, collection: true), mapping:, version:)
          end
        end
      end

      private

      attr_reader :item, :schema_options, :properties, :type
    end
  end
end

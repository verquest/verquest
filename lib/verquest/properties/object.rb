# frozen_string_literal: true

module Verquest
  module Properties
    # Object property type for structured data
    #
    # Represents a complex object with nested properties in the schema.
    # Used for defining structured data objects with multiple fields.
    #
    # @example Define an address object with nested properties
    #   address = Verquest::Properties::Object.new(name: :address)
    #   address.add(Verquest::Properties::Field.new(name: :street, type: :string))
    #   address.add(Verquest::Properties::Field.new(name: :city, type: :string, required: true))
    class Object < Base
      # Initialize a new Object property
      #
      # @param name [String, Symbol] The name of the property
      # @param required [Boolean, Array<Symbol>] Whether this property is required, or array of dependency names
      # @param nullable [Boolean] Whether this property can be null
      # @param map [String, nil] The mapping path for this property
      # @param schema_options [Hash] Additional JSON schema options for this property
      def initialize(name:, required: false, nullable: false, map: nil, **schema_options)
        @properties = {}

        @name = name.to_s
        @required = required
        @nullable = nullable
        @map = map
        @schema_options = {
          additionalProperties: Verquest.configuration.default_additional_properties
        }.merge(schema_options)
          .delete_if { |_, v| v.nil? }
          .transform_keys(&:to_s)

        @type = if nullable
          %w[object null]
        else
          "object"
        end
      end

      # Add a child property to this object
      #
      # @param property [Verquest::Properties::Base] The property to add to this object
      # @return [Verquest::Properties::Base] The added property
      def add(property)
        properties[property.name.to_s] = property
      end

      # Generate JSON schema definition for this object property
      #
      # @return [Hash] The schema definition for this object property
      def to_schema
        {
          name => {
            "type" => type,
            "required" => required_properties,
            "properties" => properties.transform_values { |property| property.to_schema[property.name] }
          }.merge(schema_options).tap do |schema|
            schema["dependentRequired"] = dependent_required_properties if dependent_required_properties.any?
          end
        }
      end

      # Generate validation schema for this object property
      #
      # @param version [String, nil] The version to generate validation schema for
      # @return [Hash] The validation schema for this object property
      def to_validation_schema(version: nil)
        {
          name => {
            "type" => type,
            "required" => required_properties,
            "properties" => properties.transform_values { |property| property.to_validation_schema(version: version)[property.name] }
          }.merge(schema_options).tap do |schema|
            schema["dependentRequired"] = dependent_required_properties if dependent_required_properties.any?
          end
        }
      end

      # Create mapping for this object property and all its children
      #
      # @param key_prefix [Array<String>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String, nil] The version to create mapping for
      # @return [void]
      def mapping(key_prefix:, value_prefix:, mapping:, version: nil)
        properties.values.each do |property|
          property.mapping(key_prefix: key_prefix + [name], value_prefix: mapping_value_prefix(value_prefix:), mapping:, version:)
        end
      end

      private

      attr_reader :type, :schema_options, :properties
    end
  end
end

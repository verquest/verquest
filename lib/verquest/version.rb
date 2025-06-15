# frozen_string_literal: true

module Verquest
  # Represents a specific version of an API request schema
  #
  # The Version class manages the properties, schema generation, and mapping
  # for a specific version of an API request. It holds the collection of
  # properties that define the request structure and handles
  # transforming between different property naming conventions.
  #
  # @example
  #   version = Verquest::Version.new(name: "2023-01")
  #   version.add(Verquest::Properties::Field.new(name: :email, type: :string))
  #   version.prepare
  #
  #   # Generate schema
  #   schema = version.schema
  #
  #   # Get mapping
  #   mapping = version.mapping
  class Version
    # @!attribute [r] name
    #   @return [String] The name/identifier of the version (e.g., "2023-01")
    #
    # @!attribute [r] properties
    #   @return [Hash<Symbol, Verquest::Properties::Base>] The properties that define the version's schema
    #
    # @!attribute [r] schema
    #   @return [Hash] The generated JSON schema for this version
    #
    # @!attribute [r] validation_schema
    #   @return [Hash] The schema used for request validation
    #
    # @!attribute [r] mapping
    #   @return [Hash] The mapping from schema property paths to internal paths
    #
    # @!attribute [r] transformer
    #   @return [Verquest::Transformer] The transformer that applies the mapping
    attr_reader :name, :properties, :schema, :validation_schema, :mapping, :transformer

    # @!attribute [rw] schema_options
    #   @return [Hash] Additional JSON schema options for this version
    #
    # @!attribute [rw] description
    #   @return [String] Description of this version
    attr_accessor :schema_options, :description

    # Initialize a new Version instance
    #
    # @param name [String] The name/identifier of the version
    # @return [Version] A new Version instance
    def initialize(name:)
      @name = name
      @schema_options = {}
      @properties = {}
    end

    # Add a property to this version
    #
    # @param property [Verquest::Properties::Base] The property to add
    # @return [Verquest::Properties::Base] The added property
    def add(property)
      properties[property.name] = property
    end

    # Remove a property from this version by name
    #
    # @param property_name [Symbol, String] The name of the property to remove
    # @return [Verquest::Properties::Base] The removed property
    # @raise [PropertyNotFoundError] If the property doesn't exist
    def remove(property_name)
      properties.delete(property_name) || raise(PropertyNotFoundError.new("Property '#{property_name}' is not defined on '#{name}"))
    end

    # Check if this version has a property with the given name
    #
    # @param property_name [Symbol, String] The name of the property to check
    # @return [Boolean] true if the property exists, false otherwise
    def has?(property_name)
      properties.key?(property_name)
    end

    # Copy properties from another version
    #
    # @param version [Verquest::Version] The version to copy properties from
    # @param exclude_properties [Array<Symbol>] Names of properties to not copy
    # @return [void]
    # @raise [ArgumentError] If version is not a Verquest::Version instance
    def copy_from(version, exclude_properties: [])
      raise ArgumentError, "Expected a Verquest::Version instance" unless version.is_a?(Version)

      version.properties.values.each do |property|
        next if exclude_properties.include?(property.name)

        add(property)
      end
    end

    # Prepare this version by generating schema and creating transformer
    #
    # @return [void]
    def prepare
      return if frozen?

      prepare_schema
      prepare_validation_schema
      prepare_mapping
      @transformer = Transformer.new(mapping: mapping)

      freeze
    end

    # Validate the schema against the metaschema
    #
    # @return [Boolean] true if the schema is valid, false otherwise
    def validate_schema
      schema_name = Verquest.configuration.json_schema_version

      metaschema = JSON::Validator.validator_for_name(schema_name).metaschema
      JSON::Validator.validate(metaschema, validation_schema)
    end

    # Validate request parameters against the version's validation schema
    #
    # @param params [Hash] The request parameters to validate
    # @param component_reference [String] A reference string for components in the schema
    # @param remove_extra_root_keys [Boolean] Whether to remove extra keys not in the schema
    # @return [Array<Hash>] An array of validation error details, or empty if valid
    def validate_params(params:, component_reference:, remove_extra_root_keys:)
      schema_name = Verquest.configuration.json_schema_version

      result = JSON::Validator.fully_validate(validation_schema, params, version: schema_name, errors_as_objects: true)
      return result if result.empty?

      result.map do |error|
        schema = error.delete(:schema)
        error[:message].gsub!(schema.to_s, component_reference)
      end
    end

    # Get the mapping for a specific property
    #
    # @param property [Symbol, String] The property name to get the mapping for
    # @return [Hash] The mapping for the property
    # @raise [PropertyNotFoundError] If the property doesn't exist
    def mapping_for(property)
      raise PropertyNotFoundError.new("Property '#{property}' is not defined on '#{name}'") unless has?(property)

      {}.tap do |mapping|
        properties[property].mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: name)
      end
    end

    # Map request parameters to internal representation using the transformer
    #
    # @param params [Hash] The request parameters to map
    # @return [Hash] The mapped parameters
    def map_params(params)
      transformer.call(params)
    end

    private

    # Generates the JSON schema for this version
    #
    # Creates a schema object with type, description, required properties,
    # and property definitions based on the properties in this version.
    # The schema is frozen to prevent modification after preparation.
    #
    # @return [Hash] The frozen schema hash
    def prepare_schema
      @schema = {
        type: :object,
        description: description,
        required: properties.values.select(&:required).map(&:name),
        properties: properties.transform_values { |property| property.to_schema[property.name] }
      }.merge(schema_options).freeze
    end

    # Generates the validation schema for this version
    #
    # Similar to prepare_schema but specifically for validation purposes.
    # The validation schema will include all referenced components and properties.
    #
    # @return [Hash] The frozen validation schema hash
    def prepare_validation_schema
      @validation_schema = {
        type: :object,
        description: description,
        required: properties.values.select(&:required).map(&:name),
        properties: properties.transform_values { |property| property.to_validation_schema(version: name)[property.name] }
      }.merge(schema_options).freeze
    end

    # Prepares the parameter mapping for this version
    #
    # Collects mappings from all properties in this version and checks for
    # duplicate mappings, which would cause conflicts during transformation.
    #
    # @return [Hash] The mapping from schema property paths to internal paths
    # @raise [MappingError] If duplicate mappings are detected
    def prepare_mapping
      @mapping = properties.values.each_with_object({}) do |property, mapping|
        property.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: name)
      end

      if (duplicates = mapping.keys.select { |k| mapping.values.count(k) > 1 }).any?
        raise MappingError.new("Mapping must be unique. Found duplicates in version '#{name}': #{duplicates.join(", ")}")
      end
    end
  end
end

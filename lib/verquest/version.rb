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
    include HelperMethods::RequiredProperties

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
    #
    # @!attribute [r] external_mapping
    #   @return [Hash] The mapping from internal attribute paths back to external paths
    attr_reader :name, :properties, :schema, :validation_schema, :mapping, :transformer, :external_mapping

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
      @name = name.to_s
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
      properties.delete(property_name.to_s) || raise(PropertyNotFoundError.new("Property '#{property_name}' is not defined on '#{name}'"))
    end

    # Check if this version has a property with the given name
    #
    # @param property_name [Symbol, String] The name of the property to check
    # @return [Boolean] true if the property exists, false otherwise
    def has?(property_name)
      properties.key?(property_name.to_s)
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
        next if exclude_properties.include?(property.name.to_sym)

        add(property)
      end
    end

    # Prepare this version by generating schema and creating transformer
    #
    # @return [void]
    def prepare
      return if frozen?

      unless schema_options.key?("additionalProperties")
        schema_options["additionalProperties"] = Verquest.configuration.default_additional_properties
      end

      schema_options.delete_if { |_, v| v.nil? }

      if combination?
        prepare_combination_schema
        prepare_combination_validation_schema
        prepare_combination_mapping
        prepare_combination_external_mapping
        @transformer = Transformer.new(mapping: mapping, discriminator: combination_discriminator)
      else
        prepare_schema
        prepare_validation_schema
        prepare_mapping
        prepare_external_mapping
        @transformer = Transformer.new(mapping: mapping)
      end

      freeze
    end

    # Validate the schema against the metaschema
    #
    # @return [Boolean] true if the schema is valid, false otherwise
    def valid_schema?
      JSONSchemer.valid_schema?(
        validation_schema,
        meta_schema: Verquest.configuration.json_schema_uri
      )
    end

    # Validate the schema against the metaschema and return detailed errors
    #
    # This method validates the schema against the configured JSON Schema metaschema
    # and returns detailed validation errors if any are found. It uses the JSONSchemer
    # library with the schema version specified in the configuration.
    #
    # @return [Array<Hash>] An array of validation error details, empty if schema is valid
    # @see #valid_schema?
    def validate_schema
      JSONSchemer.validate_schema(
        validation_schema,
        meta_schema: Verquest.configuration.json_schema_uri
      ).map do |error|
        {
          pointer: error["data_pointer"],
          type: error["type"],
          message: error["error"],
          details: error["details"]
        }
      end
    end

    # Validate request parameters against the version's validation schema
    #
    # @param params [Hash] The request parameters to validate
    # @return [Array<Hash>] An array of validation error details, or empty if valid
    def validate_params(params:)
      schemer = JSONSchemer.schema(
        validation_schema,
        meta_schema: Verquest.configuration.json_schema_uri,
        insert_property_defaults: Verquest.configuration.insert_property_defaults
      )

      schemer.validate(params).map do |error|
        {
          pointer: error["data_pointer"],
          type: error["type"],
          message: error["error"],
          details: error["details"]
        }
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
        properties[property.to_s].mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: name)
      end
    end

    # Map request parameters to internal representation using the transformer
    #
    # @param params [Hash] The request parameters to map
    # @return [Hash] The mapped parameters
    def map_params(params)
      transformer.call(params)
    end

    # Check if this version is a combination schema (root-level oneOf)
    #
    # A combination schema has a single root-level oneOf property (name is nil)
    # where the entire request body matches one of the defined schemas.
    #
    # @return [Boolean] true if this is a combination schema
    def combination?
      return @_combination if defined?(@_combination)

      @_combination = properties.values.count == 1 &&
        properties.values.first&.is_a?(Verquest::Properties::OneOf) &&
        properties.values.first.name.nil?
    end

    # Check if this version has a nested oneOf property (oneOf with a name)
    #
    # @return [Boolean] true if there's a nested oneOf property
    def has_nested_one_of?
      nested_one_of_count > 0
    end

    # Check if this version has multiple nested oneOf properties
    #
    # @return [Boolean] true if there are multiple nested oneOf properties
    def has_multiple_nested_one_of?
      nested_one_of_count > 1
    end

    # Returns the count of nested oneOf properties (computed once and cached)
    #
    # @return [Integer] Number of nested oneOf properties
    def nested_one_of_count
      return @_nested_one_of_count if defined?(@_nested_one_of_count)

      @_nested_one_of_count = properties.values.count do |p|
        p.is_a?(Verquest::Properties::OneOf) && !p.name.nil?
      end
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
        "type" => "object",
        "required" => required_properties,
        "properties" => properties.transform_values { |property| property.to_schema[property.name] }
      }.merge(schema_options).tap do |schema|
        schema["dependentRequired"] = dependent_required_properties if dependent_required_properties.any?
        schema["description"] = description if description
      end.freeze
    end

    # Generates the JSON schema for combination schemas (oneOf at root level)
    #
    # For combination schemas, the schema is delegated directly to the oneOf
    # property since it represents the entire request structure.
    #
    # @return [Hash] The schema from the oneOf property
    def prepare_combination_schema
      @schema = properties.values.first.to_schema
    end

    # Generates the validation schema for this version
    #
    # Similar to prepare_schema but specifically for validation purposes.
    # The validation schema will include all referenced components and properties.
    #
    # @return [Hash] The frozen validation schema hash
    def prepare_validation_schema
      @validation_schema = {
        "type" => "object",
        "required" => required_properties,
        "properties" => properties.transform_values { |property| property.to_validation_schema(version: name)[property.name] }
      }.merge(schema_options).tap do |schema|
        schema["dependentRequired"] = dependent_required_properties if dependent_required_properties.any?
        schema["description"] = description if description
      end.freeze
    end

    # Generates the validation schema for combination schemas (oneOf at root level)
    #
    # For combination schemas, the validation schema is delegated directly to
    # the oneOf property, which includes inline schema definitions for each option.
    #
    # @return [Hash] The validation schema from the oneOf property
    def prepare_combination_validation_schema
      @validation_schema = properties.values.first.to_validation_schema(version: name)
    end

    # Prepares the parameter mapping for this version
    #
    # Collects mappings from all properties in this version and checks for
    # duplicate mappings, which would cause conflicts during transformation.
    #
    # When nested oneOf properties are present, the mapping includes a _oneOfs array
    # containing each oneOf's metadata and variant mappings, plus base properties.
    #
    # @return [Hash] The mapping from schema property paths to internal paths
    # @raise [MappingError] If duplicate mappings are detected
    def prepare_mapping
      # Separate oneOf properties from regular properties
      one_of_properties = properties.values.select { |p| p.is_a?(Verquest::Properties::OneOf) }
      regular_properties = properties.values.reject { |p| p.is_a?(Verquest::Properties::OneOf) }

      if one_of_properties.size == 1
        prepare_single_nested_one_of_mapping(one_of_properties.first, regular_properties)
      elsif one_of_properties.size > 1
        prepare_multiple_nested_one_of_mapping(one_of_properties, regular_properties)
      else
        prepare_flat_mapping(regular_properties)
      end
    end

    # Prepares mapping for versions with a single nested oneOf property (legacy format)
    #
    # @param one_of_property [Verquest::Properties::OneOf] The nested oneOf property
    # @param regular_properties [Array<Verquest::Properties::Base>] Non-oneOf properties
    # @return [void]
    def prepare_single_nested_one_of_mapping(one_of_property, regular_properties)
      # Collect regular property mappings
      regular_mapping = {}
      regular_properties.each do |property|
        property.mapping(key_prefix: [], value_prefix: [], mapping: regular_mapping, version: name)
      end

      # Collect oneOf property mappings
      one_of_mapping = {}
      one_of_property.mapping(key_prefix: [], value_prefix: [], mapping: one_of_mapping, version: name)

      # Merge regular mappings into each oneOf variant
      @mapping = {}

      # Preserve metadata keys
      %w[_discriminator _variant_schemas _variant_path _nullable _nullable_path _nullable_target_path].each do |metadata_key|
        @mapping[metadata_key] = one_of_mapping[metadata_key] if one_of_mapping.key?(metadata_key)
      end

      one_of_mapping.each do |discriminator_value, variant_mapping|
        next if discriminator_value.start_with?("_") # Skip metadata keys

        @mapping[discriminator_value] = regular_mapping.merge(variant_mapping)
      end
    end

    # Prepares mapping for versions with multiple nested oneOf properties
    #
    # @param one_of_properties [Array<Verquest::Properties::OneOf>] The nested oneOf properties
    # @param regular_properties [Array<Verquest::Properties::Base>] Non-oneOf properties
    # @return [void]
    def prepare_multiple_nested_one_of_mapping(one_of_properties, regular_properties)
      @mapping = {}

      # Collect regular property mappings at root level
      regular_properties.each do |property|
        property.mapping(key_prefix: [], value_prefix: [], mapping: @mapping, version: name)
      end

      # Collect each oneOf's mapping into _oneOfs array
      @mapping["_oneOfs"] = one_of_properties.map do |one_of_property|
        one_of_mapping = {}
        one_of_property.mapping(key_prefix: [], value_prefix: [], mapping: one_of_mapping, version: name)
        one_of_mapping
      end
    end

    # Prepares flat mapping for versions without nested oneOf
    #
    # @param properties_list [Array<Verquest::Properties::Base>] Properties to map
    # @return [void]
    # @raise [MappingError] If duplicate mappings are detected
    def prepare_flat_mapping(properties_list)
      @mapping = properties_list.each_with_object({}) do |property, mapping|
        property.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: name)
      end

      seen = Set.new
      duplicates = mapping.values.select { |v| !seen.add?(v) }
      if duplicates.any?
        raise MappingError.new("Mapping must be unique. Found duplicates in version '#{name}': #{duplicates.uniq.join(", ")}")
      end
    end

    # Prepares the inverted parameter mapping for this version
    #
    # Inverts the standard mapping to create a reverse lookup from internal
    # attribute names back to external parameter names. This is useful when
    # transforming internal data back to the external API representation.
    #
    # For nested oneOf schemas, inverts each discriminator value's mapping.
    # Skips metadata keys that are not variant mappings.
    #
    # @return [Hash] The frozen inverted mapping where keys are internal attribute
    #   paths and values are the corresponding external schema paths
    # @see #prepare_mapping
    def prepare_external_mapping
      @external_mapping = if has_multiple_nested_one_of?
        invert_multiple_one_of_mapping
      elsif has_nested_one_of?
        invert_single_one_of_mapping
      else
        mapping.invert.freeze
      end
    end

    # Inverts mapping for single nested oneOf
    #
    # @return [Hash] The inverted mapping
    def invert_single_one_of_mapping
      mapping.each_with_object({}) do |(key, value), result|
        result[key] = if key.start_with?("_")
          value
        else
          value.invert
        end
      end.freeze
    end

    # Inverts mapping for multiple nested oneOf
    #
    # @return [Hash] The inverted mapping
    def invert_multiple_one_of_mapping
      result = {}

      mapping.each do |key, value|
        if key == "_oneOfs"
          result["_oneOfs"] = value.map do |one_of_mapping|
            one_of_mapping.each_with_object({}) do |(k, v), inverted|
              inverted[k] = if k.start_with?("_")
                v
              else
                v.invert
              end
            end
          end
        elsif key.start_with?("_")
          result[key] = value
        else
          result[value] = key # Invert base properties
        end
      end

      result.freeze
    end

    # Prepares the parameter mapping for combination schemas (oneOf)
    #
    # For combination schemas, the mapping is keyed by the discriminator value
    # so the transformer can select the appropriate mapping based on the input.
    #
    # @return [Hash] A hash where keys are discriminator values and values are mapping hashes
    def prepare_combination_mapping
      @mapping = {}
      properties.values.first.mapping(key_prefix: [], value_prefix: [], mapping: @mapping, version: name)
    end

    # Prepares the inverted parameter mapping for combination schemas
    #
    # For combination schemas, inverts each discriminator value's mapping.
    # Skips metadata keys that are not variant mappings.
    #
    # @return [Hash] The frozen inverted mapping for each discriminator value
    def prepare_combination_external_mapping
      @external_mapping = mapping.each_with_object({}) do |(key, value), result|
        # Skip metadata keys, only invert variant mapping hashes
        result[key] = if key.start_with?("_")
          value
        else
          value.invert
        end
      end.freeze
    end

    # Returns the discriminator property name for combination schemas
    #
    # @return [String, nil] The discriminator property name
    def combination_discriminator
      return nil unless combination?

      properties.values.first.send(:discriminator)
    end
  end
end

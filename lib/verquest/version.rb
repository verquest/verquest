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
    include HelperMethods::ConditionalProperties
    include HelperMethods::UnnamedOneOf

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
    #
    # @!attribute [r] location
    #   @return [Symbol] Where the params come from, `:body`, `:query` or `:path`
    attr_reader :name, :properties, :schema, :validation_schema, :mapping, :transformer, :external_mapping, :location

    # @!attribute [rw] schema_options
    #   @return [Hash] Additional JSON schema options for this version
    #
    # @!attribute [rw] description
    #   @return [String] Description of this version
    attr_accessor :schema_options, :description

    # Initialize a new Version instance
    #
    # @param name [String] The name/identifier of the version
    # @param location [Symbol] Where the params come from, `:body`, `:query` or `:path`
    # @return [Version] A new Version instance
    def initialize(name:, location: :body)
      @name = name.to_s
      @location = location
      @schema_options = {}
      @properties = {}
      @conditions = []
      # Filled after the version is frozen, so it is created here; freeze is shallow
      @validation_schemers = {}
      @validation_schemers_lock = Mutex.new
    end

    # Add a property to this version
    #
    # @param property [Verquest::Properties::Base] The property to add
    # @return [Verquest::Properties::Base] The added property
    def add(property)
      check_unnamed_one_of(property)
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

    # Returns the regular properties followed by the branch properties
    #
    # Stored when the version is prepared, because the version is frozen
    # afterwards and `process` reads it on every request.
    #
    # @return [Hash<String, Verquest::Properties::Base>] All properties listed in the schema
    def all_properties
      @all_properties || super
    end

    # Copy properties and conditions from another version
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

      version.conditions.each { |condition| add_condition(condition) }
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
      @all_properties = all_properties

      if combination?
        prepare_combination_schema
        prepare_combination_validation_schema
        prepare_combination_mapping
        prepare_combination_external_mapping
      else
        prepare_schema
        prepare_validation_schema
        prepare_mapping
        prepare_external_mapping
      end

      prepare_parameters if parameters?
      @property_defaults = property_defaults?(validation_schema)
      @transformer = Transformer.new(layout: transformer_layout)
      freeze
    end

    # Validate the schema against the metaschema
    #
    # Under `:openapi30` the document (`schema`) is checked, since the validation schema keeps JSON Schema forms
    # OpenAPI 3.0 forbids, such as "null" types.
    #
    # @return [Boolean] true if the schema is valid, false otherwise
    def valid_schema?
      JSONSchemer.valid_schema?(
        checked_schema,
        meta_schema: Verquest.configuration.json_schema_uri
      )
    end

    # Validate the schema against the metaschema and return detailed errors
    #
    # This method validates the schema against the configured JSON Schema metaschema
    # and returns detailed validation errors if any are found. It uses the JSONSchemer
    # library with the schema version specified in the configuration. Under `:openapi30` it checks the document,
    # so the pointers refer to `schema`.
    #
    # @return [Array<Hash>] An array of validation error details, empty if schema is valid
    # @see #valid_schema?
    def validate_schema
      JSONSchemer.validate_schema(
        checked_schema,
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
    # Inserts missing defaults into params when {#inserts_property_defaults?} is true.
    #
    # @param params [Hash] The request parameters to validate
    # @return [Array<Hash>] An array of validation error details, or empty if valid
    def validate_params(params:)
      validation_schemer.validate(params).map do |error|
        {
          pointer: error["data_pointer"],
          type: error["type"],
          message: error["error"],
          details: error["details"]
        }
      end
    end

    # Check if validating params inserts the defaults the schema declares
    #
    # @return [Boolean] true when the schema declares a default and the configuration inserts defaults
    def inserts_property_defaults?
      !!insert_property_defaults_setting
    end

    # Get the mapping for a specific property
    #
    # @param property [Symbol, String] The property name (regular or declared in a condition branch)
    # @return [Hash] The mapping for the property
    # @raise [PropertyNotFoundError] If the property doesn't exist
    def mapping_for(property)
      {}.tap do |mapping|
        fetch_property(property).mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: name)
      end
    end

    # Get a property by name
    #
    # @param property [Symbol, String] The property name (regular or declared in a condition branch)
    # @return [Verquest::Properties::Base] The property
    # @raise [PropertyNotFoundError] If the property doesn't exist
    def fetch_property(property)
      all_properties.fetch(property.to_s) do
        raise PropertyNotFoundError.new("Property '#{property}' is not defined on '#{name}'")
      end
    end

    # Check if this version reads its params from the query string or the path
    #
    # @return [Boolean] true for a query or path version
    def parameters?
      location != :body
    end

    # Converts query or path strings to the types the validation schema expects
    #
    # @param params [Hash] The parsed request parameters
    # @return [Hash] Converted params for a query or path version, the same params otherwise
    def coerce_params(params)
      parameters? ? query_coercer.call(params) : params
    end

    # Returns OpenAPI parameter objects for this query or path version, in OpenAPI 3.0 forms under :openapi30
    #
    # @return [Array<Hash>] A new array of parameter objects on each call
    def parameters
      Query::Parameters.new(schema: document_schema(validation_schema), options: query_options, location:).call
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

    # Returns the count of nested oneOf properties
    #
    # Not memoized, because the version is frozen once it is prepared.
    #
    # @return [Integer] Number of nested oneOf properties
    def nested_one_of_count
      properties.values.count do |p|
        p.is_a?(Verquest::Properties::OneOf) && !p.name.nil?
      end
    end

    private

    # @return [Verquest::Query::Coercer, nil] The coercer of a query or path version
    attr_reader :query_coercer

    # @return [Hash{Array<String> => Hash}, nil] The parameter options of each property path of a query or path version
    attr_reader :query_options

    # Checks a query or path version and builds its coercer
    #
    # @return [void]
    # @raise [Verquest::DefinitionError] If the version uses a shape its location can't express
    def prepare_parameters
      Query::DefinitionCheck.new(self).call

      @query_options = all_properties.each_value.with_object({}) do |property, options|
        options.merge!(property.query_options(prefix: [], version: name))
      end.freeze
      explodes = query_options.filter_map { |path, options| [path, options[:explode]] if options.key?(:explode) }.to_h
      @query_coercer = Query::Coercer.new(schema: validation_schema, explodes:)
    end

    # Returns the compiled validation schema for the current configuration
    #
    # Compiling is much slower than validating, so each configuration is
    # compiled once and reused. Default insertion is turned off when the schema
    # declares no default, since json_schemer would walk every result for
    # nothing. The lock keeps threads from compiling at the same time.
    #
    # @return [JSONSchemer::Schema] The compiled validation schema
    def validation_schemer
      key = [Verquest.configuration.json_schema_uri, insert_property_defaults_setting]

      @validation_schemers_lock.synchronize do
        @validation_schemers[key] ||= JSONSchemer.schema(validation_schema, meta_schema: key[0], insert_property_defaults: key[1])
      end
    end

    # Returns the insert_property_defaults value to compile with
    #
    # @return [Boolean, Symbol] The configured value when the schema declares a default, false otherwise
    def insert_property_defaults_setting
      @property_defaults ? Verquest.configuration.insert_property_defaults : false
    end

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
        **required_keyword,
        "properties" => all_properties.transform_values { |property| property.to_schema[property.name] }
      }.merge(schema_options).tap do |schema|
        schema["dependentRequired"] = dependent_required_properties if dependent_required_properties.any?
        schema["description"] = description if description
        add_conditions(schema, documentation: true)
      end
      @schema = document_schema(@schema).freeze
    end

    # Generates the JSON schema for combination schemas (oneOf at root level)
    #
    # For combination schemas, the schema is delegated directly to the oneOf
    # property since it represents the entire request structure.
    #
    # @return [Hash] The schema from the oneOf property
    # @raise [ArgumentError] If the version also has conditions
    def prepare_combination_schema
      raise ArgumentError, "Conditions can not be declared next to a root-level one_of" if conditions.any?

      @schema = document_schema(properties.values.first.to_schema)
    end

    # @return [Hash] The schema the meta-schema checks: the document under OpenAPI 3.0, the validation schema otherwise
    def checked_schema
      Verquest.configuration.nullable_keyword? ? schema : validation_schema
    end

    # Converts a document to OpenAPI 3.0 forms when the configured version needs them
    #
    # @param schema [Hash] The schema in JSON Schema forms
    # @return [Hash] The schema for documents
    def document_schema(schema)
      Verquest.configuration.nullable_keyword? ? Openapi30.document(schema) : schema
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
        **required_keyword,
        "properties" => all_properties.transform_values { |property| property.to_validation_schema(version: name)[property.name] }
      }.merge(schema_options).tap do |schema|
        schema["dependentRequired"] = dependent_required_properties if dependent_required_properties.any?
        schema["description"] = description if description
        add_conditions(schema)
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

    # Checks whether a schema declares a default anywhere
    #
    # A property named `default` also counts, which only keeps default insertion on.
    #
    # @param schema [Object] The schema or a part of it
    # @return [Boolean] true if any Hash in it has a "default" key
    def property_defaults?(schema)
      case schema
      when Hash then schema.key?("default") || schema.each_value.any? { |value| property_defaults?(value) }
      when Array then schema.any? { |value| property_defaults?(value) }
      else false
      end
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
      one_of_properties = all_properties.values.select { |p| p.is_a?(Verquest::Properties::OneOf) }
      regular_properties = all_properties.values.reject { |p| p.is_a?(Verquest::Properties::OneOf) }

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
      return prepare_multiple_nested_one_of_mapping([one_of_property], regular_properties) if regular_mapping.key?("_oneOfs")

      # Collect oneOf property mappings
      one_of_mapping = {}
      one_of_property.mapping(key_prefix: [], value_prefix: [], mapping: one_of_mapping, version: name)

      # Merge regular mappings into each oneOf variant
      @mapping = {}

      # Preserve metadata keys
      Transformer::METADATA_KEYS.each do |metadata_key|
        @mapping[metadata_key] = one_of_mapping[metadata_key] if one_of_mapping.key?(metadata_key)
      end

      one_of_mapping.each do |discriminator_value, variant_mapping|
        next if Transformer::METADATA_KEYS.include?(discriminator_value)

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

      # Collect each oneOf's mapping into _oneOfs array, after the ones nested in objects
      @mapping["_oneOfs"] = @mapping.fetch("_oneOfs", []) + one_of_properties.map do |one_of_property|
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
      duplicates = mapping.except(*Transformer::METADATA_KEYS).values.select { |v| !seen.add?(v) }
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
      # A single top-level oneOf is keyed by variant; any other mapping is a path mapping, with oneOfs in _oneOfs.
      @external_mapping = if has_nested_one_of? && !mapping.key?("_oneOfs")
        invert_one_of_mapping(mapping)
      else
        invert_path_mapping(mapping)
      end.freeze
    end

    # Inverts the source and target pairs of a mapping, and the oneOfs in its `_oneOfs`
    #
    # A path mapping holds only pairs and `_oneOfs`; a oneOf's other metadata
    # sits in its own mapping, which {#invert_one_of_mapping} keeps as it is.
    #
    # @param path_mapping [Hash] The mapping of source paths to target paths
    # @return [Hash] The inverted mapping
    def invert_path_mapping(path_mapping)
      path_mapping.each_with_object({}) do |(key, value), result|
        if key == "_oneOfs"
          result[key] = value.map { |one_of_mapping| invert_one_of_mapping(one_of_mapping) }
        else
          result[value] = key
        end
      end
    end

    # Inverts each variant mapping of a oneOf mapping, keeping its metadata
    #
    # @param one_of_mapping [Hash] The oneOf mapping (variant name => variant mapping, plus metadata)
    # @return [Hash] The oneOf mapping with each variant mapping inverted
    def invert_one_of_mapping(one_of_mapping)
      one_of_mapping.to_h do |key, value|
        [key, Transformer::METADATA_KEYS.include?(key) ? value : invert_path_mapping(value)]
      end
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
      @external_mapping = invert_one_of_mapping(mapping).freeze
    end

    # Returns the full paths of this version's properties for the transformer
    #
    # @return [Verquest::Transformer::Layout] The layout
    def transformer_layout
      Transformer::Layout.new.tap do |layout|
        all_properties.each_value do |property|
          property.layout(key_prefix: [], value_prefix: [], layout:, version: name)
        end
      end
    end
  end
end

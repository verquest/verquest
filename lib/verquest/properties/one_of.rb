# frozen_string_literal: true

module Verquest
  module Properties
    # OneOf property type for polymorphic schemas
    #
    # Implements JSON Schema's oneOf keyword for defining polymorphic request structures
    # where exactly one of multiple schemas must match. Supports optional discriminator-based
    # schema selection using a property value to determine which schema applies.
    #
    # According to JSON Schema specification, oneOf validates that the data is valid against
    # exactly one of the subschemas. The discriminator is an OpenAPI extension that helps
    # with efficient schema resolution but is not required for basic oneOf validation.
    #
    # When used at the root level (without a name), it creates a "combination schema"
    # where the entire request body can match one of the defined schemas.
    #
    # @example Root-level oneOf with discriminator
    #   one_of = Verquest::Properties::OneOf.new(discriminator: "type")
    #   one_of.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    #   one_of.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))
    #
    # @example Nested oneOf property
    #   one_of = Verquest::Properties::OneOf.new(
    #     name: :payment,
    #     discriminator: "method",
    #     required: true
    #   )
    #
    # @example oneOf without discriminator (pure JSON Schema validation)
    #   one_of = Verquest::Properties::OneOf.new(name: :value)
    #   # Validates that exactly one schema matches
    class OneOf < Base
      # JSON Schema for null type, used when nullable is true
      NULL_TYPE_SCHEMA = {"type" => "null"}.freeze

      # @return [String, nil] The discriminator property name for schema selection
      attr_reader :discriminator

      # Initialize a new OneOf property
      #
      # @param name [String, Symbol, nil] The property name, or nil for root-level oneOf
      # @param discriminator [String, Symbol, nil] The property name used to discriminate between schemas.
      #   When omitted, the transformer infers the variant by validating against each schema.
      # @param required [Boolean, Array<Symbol>] Whether this property is required, or array of dependency names
      # @param nullable [Boolean] Whether this property can be null
      # @param map [String, nil] The mapping path for this property
      def initialize(name: nil, discriminator: nil, required: false, nullable: false, map: nil)
        @name = name&.to_s
        @required = required
        @nullable = nullable
        @map = map
        @discriminator = discriminator&.to_s
        @schemas = {}
      end

      # Add a schema option to this oneOf
      #
      # Both Reference and Object properties are allowed at any level.
      # Object properties define inline schemas directly within the oneOf.
      #
      # @param schema [Verquest::Properties::Reference, Verquest::Properties::Object] The schema to add
      # @raise [ArgumentError] If schema is neither a Reference nor an Object
      # @return [Verquest::Properties::Base] The added schema
      def add(schema)
        unless schema.is_a?(Verquest::Properties::Reference) || schema.is_a?(Verquest::Properties::Object)
          raise ArgumentError, "Must be a Reference or Object property"
        end

        schemas[schema.name] = schema
      end

      # Generate JSON schema definition for this oneOf property
      #
      # @return [Hash] The schema definition with oneOf array and optional discriminator
      def to_schema
        freeze_schemas
        wrap_schema(build_schema_with_refs)
      end

      # Generate validation schema for this oneOf property
      #
      # Unlike to_schema which uses $ref, the validation schema includes
      # the full inline schema definitions for each option.
      #
      # @param version [String, nil] The version to generate validation schema for
      # @return [Hash] The validation schema with inline schema definitions
      def to_validation_schema(version: nil)
        freeze_schemas
        wrap_schema(build_validation_schema(version: version))
      end

      # Create mapping for this oneOf property
      #
      # For oneOf schemas, the mapping is keyed by discriminator value so the
      # transformer can select the appropriate mapping based on the input.
      # Each discriminator value maps to a hash of source => target path mappings.
      #
      # For nested oneOf (with a name), the property name is included in the path prefixes.
      # For root-level oneOf (name is nil), paths start from the root.
      #
      # The `map` parameter on oneOf affects the target path prefix for all contained schemas.
      #
      # When no discriminator is set, the transformer will infer the variant by validating
      # the input against each schema and selecting the one that matches.
      #
      # @param key_prefix [Array<String>] Prefix for the source key paths
      # @param value_prefix [Array<String>] Prefix for the target value paths
      # @param mapping [Hash] The mapping hash to be updated (discriminator value => path mappings)
      # @param version [String, nil] The version to create mapping for
      # @return [void]
      def mapping(key_prefix:, value_prefix:, mapping:, version: nil)
        freeze_schemas
        source_prefix = compute_source_prefix(key_prefix)
        target_prefix = compute_target_prefix(value_prefix)

        build_variant_mappings(mapping, source_prefix, target_prefix, version)
        store_discriminator_path(mapping, source_prefix)
        store_variant_schemas(mapping, version) unless discriminator
        store_nullable_metadata(mapping) if nullable
      end

      # Returns validation schemas for all variants
      #
      # Used by the Transformer to infer which variant matches when no discriminator is set.
      #
      # @param version [String, nil] The version for schema resolution
      # @return [Hash<String, Hash>] Variant name => validation schema mapping
      def variant_schemas(version: nil)
        freeze_schemas
        schemas.each_with_object({}) do |(name, schema), result|
          result[name] = schema.to_validation_schema(version: version)[schema.name]
        end
      end

      private

      attr_reader :schemas

      # Freezes the schemas hash to prevent further modifications
      # This is called on first read access to ensure immutability after setup
      #
      # @return [void]
      def freeze_schemas
        schemas.freeze unless schemas.frozen?
      end

      # Check if this is a root-level oneOf (no property name)
      #
      # @return [Boolean] true if this oneOf is at the root level
      def root_level?
        name.nil?
      end

      # Wraps the schema hash with the property name if present
      #
      # @param schema [Hash] The schema to wrap
      # @return [Hash] The schema, optionally wrapped with the property name
      def wrap_schema(schema)
        root_level? ? schema : {name => schema}
      end

      # Computes the source path prefix for mapping keys
      #
      # @param key_prefix [Array<String>] The current key prefix
      # @return [Array<String>] The effective key prefix including the property name if present
      def compute_source_prefix(key_prefix)
        root_level? ? key_prefix : key_prefix + [name]
      end

      # Computes the target path prefix for mapping values
      #
      # @param value_prefix [Array<String>] The current value prefix
      # @return [Array<String>] The effective value prefix based on map or name
      def compute_target_prefix(value_prefix)
        return parse_absolute_path(@map) if absolute_path?(@map)
        return value_prefix + parse_relative_path(@map) if @map

        root_level? ? value_prefix : value_prefix + [name]
      end

      # Computes the target prefix for a specific reference's mapping
      #
      # @param reference_map [String, nil] The map parameter from the reference
      # @param base_prefix [Array<String>] The base value prefix
      # @return [Array<String>] The target prefix as an array of path segments
      def compute_reference_target_prefix(reference_map, base_prefix)
        return base_prefix if reference_map.nil?
        return parse_absolute_path(reference_map) if absolute_path?(reference_map)

        base_prefix + parse_relative_path(reference_map)
      end

      # Builds variant mappings for each schema option
      #
      # Handles both Reference and Object schemas:
      # - Reference: delegates to the referenced schema's mapping
      # - Object: builds mapping from child properties directly
      #
      # @param mapping [Hash] The mapping hash to populate
      # @param source_prefix [Array<String>] Source path prefix
      # @param target_prefix [Array<String>] Target path prefix
      # @param version [String, nil] The version for schema resolution
      # @return [void]
      def build_variant_mappings(mapping, source_prefix, target_prefix, version)
        schemas.each_value do |schema|
          if schema.is_a?(Verquest::Properties::Reference)
            build_reference_variant_mapping(mapping, schema, source_prefix, target_prefix, version)
          elsif schema.is_a?(Verquest::Properties::Object)
            build_object_variant_mapping(mapping, schema, source_prefix, target_prefix, version)
          end
        end
      end

      # Builds mapping for a Reference variant
      #
      # @param mapping [Hash] The mapping hash to populate
      # @param schema [Verquest::Properties::Reference] The reference schema
      # @param source_prefix [Array<String>] Source path prefix
      # @param target_prefix [Array<String>] Target path prefix
      # @param version [String, nil] The version for schema resolution
      # @return [void]
      def build_reference_variant_mapping(mapping, schema, source_prefix, target_prefix, version)
        reference_mapping = schema.send(:from).mapping(version: version)
        reference_map = schema.send(:map)
        variant_target_prefix = compute_reference_target_prefix(reference_map, target_prefix)

        mapping[schema.name] = build_prefixed_mapping(
          reference_mapping,
          source_prefix,
          variant_target_prefix
        )
      end

      # Builds mapping for an inline Object variant
      #
      # Unlike nested objects, inline oneOf variants map their properties directly
      # under the oneOf property path (not under oneOf/variant_name).
      # This mirrors how Reference variants work.
      #
      # @param mapping [Hash] The mapping hash to populate
      # @param schema [Verquest::Properties::Object] The object schema
      # @param source_prefix [Array<String>] Source path prefix
      # @param target_prefix [Array<String>] Target path prefix
      # @param version [String, nil] The version for schema resolution
      # @return [void]
      def build_object_variant_mapping(mapping, schema, source_prefix, target_prefix, version)
        object_mapping = {}
        object_map = schema.send(:map)
        variant_target_prefix = compute_reference_target_prefix(object_map, target_prefix)

        # Build mapping from object's child properties
        # Properties are mapped directly under source_prefix (not source_prefix + object_name)
        # to match how Reference variants work
        schema.send(:properties).each_value do |property|
          property.mapping(
            key_prefix: source_prefix,
            value_prefix: variant_target_prefix,
            mapping: object_mapping,
            version: version
          )
        end

        mapping[schema.name] = object_mapping
      end

      # Builds a mapping hash with prefixes applied to all keys and values
      #
      # @param base_mapping [Hash] The source mapping from the referenced schema
      # @param source_prefix [Array<String>] Prefix for source keys
      # @param target_prefix [Array<String>] Prefix for target values
      # @return [Hash] The mapping with prefixes applied
      def build_prefixed_mapping(base_mapping, source_prefix, target_prefix)
        base_mapping.each_with_object({}) do |(source_key, target_value), result|
          result[join_path(source_prefix, source_key)] = join_path(target_prefix, target_value)
        end
      end

      # Stores the discriminator path in the mapping for nested oneOf
      #
      # For nested oneOf (with a name) or oneOf inside a collection (source_prefix is not empty),
      # stores the discriminator path so the transformer knows where to look for the value.
      #
      # @param mapping [Hash] The mapping hash to update
      # @param source_prefix [Array<String>] The source path prefix
      # @return [void]
      def store_discriminator_path(mapping, source_prefix)
        return unless discriminator
        # Skip only for true root-level oneOf (no name AND no prefix from collection)
        return if root_level? && source_prefix.empty?

        mapping["_discriminator"] = join_path(source_prefix, discriminator)
      end

      # Stores variant schemas in the mapping for schema-based inference
      #
      # When no discriminator is set, the transformer needs access to the validation
      # schemas to determine which variant matches the input data.
      #
      # @param mapping [Hash] The mapping hash to update
      # @param version [String, nil] The version for schema resolution
      # @return [void]
      def store_variant_schemas(mapping, version)
        mapping["_variant_schemas"] = variant_schemas(version: version)
        mapping["_variant_path"] = name unless root_level?
      end

      # Stores nullable metadata in the mapping
      #
      # When nullable is true, the transformer needs to know to allow null values
      # without attempting variant resolution.
      #
      # @param mapping [Hash] The mapping hash to update
      # @return [void]
      def store_nullable_metadata(mapping)
        mapping["_nullable"] = true
        mapping["_nullable_path"] = name unless root_level?
      end

      # Joins path segments into a slash-separated path string
      #
      # @param prefix [Array<String>] The path prefix segments
      # @param suffix [String] The path suffix
      # @return [String] The combined path
      def join_path(prefix, suffix)
        prefix.empty? ? suffix : "#{prefix.join("/")}/#{suffix}"
      end

      # Checks if a path is absolute (starts with /)
      #
      # @param path [String, nil] The path to check
      # @return [Boolean] true if the path is absolute
      def absolute_path?(path)
        path&.start_with?("/")
      end

      # Parses an absolute path into segments
      #
      # @param path [String] The absolute path to parse
      # @return [Array<String>] The path segments
      def parse_absolute_path(path)
        path.delete_prefix("/").split("/").reject(&:empty?)
      end

      # Parses a relative path into segments
      #
      # @param path [String] The relative path to parse
      # @return [Array<String>] The path segments
      def parse_relative_path(path)
        path.split("/")
      end

      # Returns the JSON Schema keyword for this property type
      #
      # @return [String] Always returns "oneOf"
      def schema_keyword
        "oneOf"
      end

      # Builds the JSON schema structure with $ref references
      #
      # @return [Hash] Schema with oneOf array and optional discriminator
      def build_schema_with_refs
        schema = {schema_keyword => collect_schema_refs}
        add_discriminator_to_schema(schema)
        schema
      end

      # Builds the validation schema structure with inline definitions
      #
      # Unlike the documentation schema, the validation schema omits the discriminator
      # since it's an OpenAPI extension that JSON Schema validators ignore.
      # Validators validate against the oneOf array directly.
      #
      # @param version [String, nil] The version to generate validation schema for
      # @return [Hash] Validation schema with oneOf array (no discriminator)
      def build_validation_schema(version:)
        {schema_keyword => collect_inline_schemas(version)}
      end

      # Collects $ref schema references for all variants
      #
      # @return [Array<Hash>] Array of schema references
      def collect_schema_refs
        refs = schemas.values.map { |schema| schema.to_schema[schema.name] }
        refs << NULL_TYPE_SCHEMA if nullable
        refs
      end

      # Collects inline schema definitions for all variants
      #
      # @param version [String, nil] The version for schema resolution
      # @return [Array<Hash>] Array of inline schema definitions
      def collect_inline_schemas(version)
        inline_schemas = schemas.values.map { |schema| schema.to_validation_schema(version: version)[schema.name] }
        inline_schemas << NULL_TYPE_SCHEMA if nullable
        inline_schemas
      end

      # Adds discriminator information to the schema if present
      #
      # Only Reference schemas are included in the discriminator mapping since
      # Objects don't have $ref. This follows OpenAPI spec where discriminator
      # mapping contains only $ref strings.
      #
      # @param schema [Hash] The schema to modify
      # @return [void]
      def add_discriminator_to_schema(schema)
        return unless discriminator

        schema["discriminator"] = {
          "propertyName" => discriminator,
          "mapping" => build_discriminator_mapping
        }
      end

      # Builds the discriminator mapping with $ref values
      #
      # Only Reference schemas are included since Objects don't have $ref.
      # This follows OpenAPI spec where discriminator mapping contains only $ref strings.
      #
      # @return [Hash] The discriminator value to $ref mapping
      def build_discriminator_mapping
        schemas.each_with_object({}) do |(name, schema), mapping|
          # Only include References in discriminator mapping (Objects don't have $ref)
          next unless schema.is_a?(Verquest::Properties::Reference)

          mapping[name] = schema.to_schema[name]["$ref"]
        end
      end
    end
  end
end

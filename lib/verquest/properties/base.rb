# frozen_string_literal: true

module Verquest
  module Properties
    # Base class for all property types
    #
    # This abstract class defines the interface for all property types
    # in the Verquest schema system. All property classes should inherit
    # from this base class and implement its required methods.
    #
    # @abstract Subclass and override {#to_schema}, {#mapping} to implement
    class Base
      include HelperMethods::RequiredProperties

      # JSON Schema for null type, used when nullable is true
      NULL_TYPE_SCHEMA = {"type" => "null"}.freeze

      # @!attribute [rw] name
      #   @return [String] The name of the property
      # @!attribute [rw] required
      #   @return [Boolean] Whether this property is required
      # @!attribute [rw] map
      #   @return [String, nil] The mapping path for this property
      # @!attribute [rw] parameter_examples
      #   @return [Hash, nil] Named OpenAPI Example Objects for this property's query parameter, kept out of the JSON schemas
      # @!attribute [rw] case_insensitive
      #   @return [Boolean, nil] Whether a query value matches the enum case-insensitively
      attr_accessor :name, :required, :map, :parameter_examples, :case_insensitive

      # Adds a child property to this property
      # @abstract
      # @param property [Verquest::Properties::Base] The property to add
      # @raise [NoMethodError] This is an abstract method that must be overridden
      def add(property)
        raise NoMethodError
      end

      # Generates JSON schema for this property
      # @abstract
      # @return [Hash] The schema definition for this property
      # @raise [NoMethodError] This is an abstract method that must be overridden
      def to_schema
        raise NoMethodError
      end

      # Generates validation schema for this property, defaults to the same as `to_schema`
      # @param version [String, nil] The version to generate validation schema for
      # @return [Hash] The validation schema for this property
      def to_validation_schema(version: nil)
        to_schema
      end

      # Creates mapping for this property
      # @abstract
      # @param key_prefix [Array<String>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String, nil] The version to create mapping for
      # @return [void]
      # @raise [NoMethodError] This is an abstract method that must be overridden
      def mapping(key_prefix:, value_prefix:, mapping:, version:)
        raise NoMethodError
      end

      # Adds this property to a transformer layout
      #
      # This is the layout of a scalar property: one source and target pair.
      # Objects, collections, references and oneOfs override it.
      #
      # @param key_prefix [Array<String>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param layout [Verquest::Transformer::Layout] The layout to add to
      # @param version [String, nil] The version to create the layout for
      # @return [void]
      def layout(key_prefix:, value_prefix:, layout:, version:)
        layout.add_pair((key_prefix + [name]).join("/"), mapping_value_key(value_prefix:))
      end

      # Returns the query parameter options under this property, by path
      #
      # Options are `explode:` for arrays, `examples:` for properties with
      # parameter examples, and `case_insensitive:` for properties matching
      # their enum case-insensitively. Paths without options are left out.
      #
      # @param prefix [Array<String>] Path of the parent property
      # @param version [String] The version to resolve references with
      # @return [Hash{Array<String> => Hash}] The options of each property path
      def query_options(prefix:, version:)
        options = {examples: parameter_examples, case_insensitive: (true if case_insensitive)}.compact
        options.empty? ? {} : {prefix + [name] => options}
      end

      # Returns a copy of this property under another name and map:
      #
      # Used by a reference to a single property, so the property maps as if
      # it were declared where the reference is.
      #
      # @param name [String, Symbol] The new name
      # @param map [String, nil] The new map: option
      # @return [Verquest::Properties::Base] The renamed copy
      def renamed(name:, map:)
        dup.tap { |copy| copy.rename(name, map) }
      end

      protected

      # @param name [String, Symbol] The new name
      # @param map [String, nil] The new map: option
      # @return [void]
      def rename(name, map)
        @name = name.to_s
        @map = map
      end

      private

      # @!attribute [r] nullable
      #   @return [Boolean] Whether this property can be null
      attr_reader :nullable

      # Allows null without weakening constraints, keeping defaults available for insertion
      # @param schema [Hash] The original property schema
      # @return [Hash] The schema, optionally wrapped in a nullable union
      def nullable_schema(schema)
        return schema unless nullable

        schema.slice("default").merge("anyOf" => [schema.except("default"), NULL_TYPE_SCHEMA])
      end

      # Determines the mapping target key based on mapping configuration
      # @param value_prefix [Array<String>] Prefix for the target value
      # @return [String] The target mapping key
      def mapping_value_key(value_prefix:)
        if map.nil?
          (value_prefix + [name]).join("/")
        elsif map == "/"
          ""
        elsif map.start_with?("/")
          map.gsub(%r{^/}, "")
        else
          (value_prefix + map.split("/")).join("/")
        end
      end

      # Determines the mapping target value prefix based on mapping configuration
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param collection [Boolean] Whether this is a collection mapping
      # @return [Array<String>] The target mapping value prefix
      def mapping_value_prefix(value_prefix:, collection: false)
        value_prefix = if map.nil?
          value_prefix + [name]
        elsif map == "/"
          []
        elsif map.start_with?("/")
          map.gsub(%r{^/}, "").split("/")
        else
          value_prefix + map.split("/")
        end

        if collection && value_prefix.any?
          last = value_prefix.pop
          value_prefix.push((last.to_s + "[]").to_sym)
        end

        value_prefix
      end

      # Adds the mapping of a child property
      #
      # A oneOf gets its own mapping in the `_oneOfs` array, so its metadata
      # can't clash with another oneOf in the same mapping.
      #
      # @param property [Verquest::Properties::Base] The child property
      # @param mapping [Hash] The mapping hash to be updated
      # @param options [Hash] The key_prefix, value_prefix and version for the child mapping
      # @return [void]
      def add_child_mapping(property, mapping:, **options)
        return property.mapping(mapping:, **options) unless property.is_a?(OneOf)

        one_of_mapping = {}
        property.mapping(mapping: one_of_mapping, **options)
        (mapping["_oneOfs"] ||= []) << one_of_mapping
      end

      # Adds the mappings of a referenced request's properties under the given prefixes
      #
      # Each property maps itself with the prefixes, instead of the finished
      # mapping of the request being copied, so its oneOfs keep their
      # metadata and land in `_oneOfs`.
      #
      # @param request [Class<Verquest::Base>] The referenced request
      # @param key_prefix [Array<String>] Prefix for the source keys
      # @param value_prefix [Array<String>] Prefix for the target values
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String] The version to create mapping for
      # @return [void]
      def add_request_mapping(request, key_prefix:, value_prefix:, mapping:, version:)
        referenced = request.resolve(version)
        referenced.all_properties.each_value do |property|
          add_child_mapping(property, key_prefix:, value_prefix:, mapping:, version: referenced.name)
        end
      end

      # Adds a referenced request's properties to a layout under the given prefixes
      #
      # @param request [Class<Verquest::Base>] The referenced request
      # @param key_prefix [Array<String>] Prefix for the source keys
      # @param value_prefix [Array<String>] Prefix for the target values
      # @param layout [Verquest::Transformer::Layout] The layout to add to
      # @param version [String] The version to create the layout for
      # @return [void]
      def add_request_layout(request, key_prefix:, value_prefix:, layout:, version:)
        referenced = request.resolve(version)
        referenced.all_properties.each_value do |property|
          property.layout(key_prefix:, value_prefix:, layout:, version: referenced.name)
        end
      end
    end
  end
end

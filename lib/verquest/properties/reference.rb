# frozen_string_literal: true

module Verquest
  module Properties
    # Reference property type for schema reuse
    #
    # Allows referencing other schema definitions to promote reuse and DRY principles.
    # Can reference either a complete schema or a specific property within a schema.
    #
    # @example Reference another schema
    #   reference = Verquest::Properties::Reference.new(
    #     name: :user,
    #     from: UserRequest,
    #     required: true
    #   )
    #
    # @example Reference a specific property from another schema
    #   reference = Verquest::Properties::Reference.new(
    #     name: :address,
    #     from: UserRequest,
    #     property: :address
    #   )
    class Reference < Base
      # Initialize a new Reference property
      #
      # @param name [String, Symbol] The name of the property
      # @param from [Class] The schema class to reference
      # @param property [Symbol, nil] Optional specific property to reference
      # @param nullable [Boolean] Whether this property can be null
      # @param map [String, nil] The mapping path for this property
      # @param required [Boolean, Array<Symbol>] Whether this property is required, or array of dependency names
      def initialize(name:, from:, property: nil, nullable: false, map: nil, required: false)
        @name = name.to_s
        @from = from
        @property = property
        @nullable = nullable
        @map = map
        @required = required
      end

      # Generate JSON schema definition for this reference property
      #
      # @return [Hash] The schema definition with a $ref pointer
      def to_schema
        {name => nullable_schema({"$ref" => from.to_ref(property: property)})}
      end

      # Generate validation schema for this reference property
      #
      # @param version [String, nil] The version to generate validation schema for
      # @return [Hash] The validation schema for this reference
      def to_validation_schema(version: nil)
        schema = from.to_validation_schema(version:, property: property).dup

        {name => nullable_schema(schema)}
      end

      # Create mapping for this reference property
      #
      # The referenced request's properties map themselves under this
      # reference's prefixes. A reference to a single property maps that
      # property as if it were declared here, with this reference's name and map:.
      #
      # @param key_prefix [Array<String>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String] The version to create mapping for
      # @return [void]
      # @raise [Verquest::PropertyNotFoundError] If the referenced property doesn't exist
      def mapping(key_prefix:, value_prefix:, mapping:, version:)
        return add_request_mapping(from, key_prefix: key_prefix + [name], value_prefix: mapping_value_prefix(value_prefix:), mapping:, version:) unless property

        referenced = from.resolve(version)
        add_child_mapping(referenced.fetch_property(property).renamed(name:, map:), key_prefix:, value_prefix:, mapping:, version: referenced.name)
      end

      # Adds the referenced request's properties, or the referenced property, to a transformer layout
      #
      # @param key_prefix [Array<String>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param layout [Verquest::Transformer::Layout] The layout to add to
      # @param version [String, nil] The version to create the layout for
      # @return [void]
      # @raise [Verquest::PropertyNotFoundError] If the referenced property doesn't exist
      def layout(key_prefix:, value_prefix:, layout:, version:)
        return add_request_layout(from, key_prefix: key_prefix + [name], value_prefix: mapping_value_prefix(value_prefix:), layout:, version:) unless property

        referenced = from.resolve(version)
        referenced.fetch_property(property).renamed(name:, map:).layout(key_prefix:, value_prefix:, layout:, version: referenced.name)
      end

      # Returns the query parameter options of the referenced request, or of
      # the referenced property renamed to this reference
      #
      # This reference's own parameter examples replace the referenced ones.
      #
      # @param prefix [Array<String>] Path of the parent property
      # @param version [String] The version to resolve references with
      # @return [Hash{Array<String> => Hash}] The options of each property path
      # @raise [Verquest::PropertyNotFoundError] If the referenced property doesn't exist
      def query_options(prefix:, version:)
        referenced = from.resolve(version)
        return referenced_property_options(referenced, prefix:) if property

        referenced.all_properties.each_value.with_object(super) do |child, options|
          options.merge!(child.query_options(prefix: prefix + [name], version: referenced.name))
        end
      end

      private

      attr_reader :from, :property

      # @return [Hash{Array<String> => Hash}] The options of the referenced property under this reference's name
      def referenced_property_options(referenced, prefix:)
        copy = referenced.fetch_property(property).renamed(name:, map:)
        copy.parameter_examples = parameter_examples if parameter_examples

        copy.query_options(prefix:, version: referenced.name)
      end
    end
  end
end

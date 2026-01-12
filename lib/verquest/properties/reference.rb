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
        if nullable
          {
            name => {
              "oneOf" => [
                {"$ref" => from.to_ref(property: property)},
                {"type" => "null"}
              ]
            }
          }
        else
          {
            name => {"$ref" => from.to_ref(property: property)}
          }
        end
      end

      # Generate validation schema for this reference property
      #
      # @param version [String, nil] The version to generate validation schema for
      # @return [Hash] The validation schema for this reference
      def to_validation_schema(version: nil)
        schema = from.to_validation_schema(version:, property: property).dup

        if nullable
          schema["type"] = [schema["type"], "null"] unless schema["type"].include?("null")
        end

        {
          name => schema
        }
      end

      # Create mapping for this reference property
      # This delegates to the referenced schema's mapping with appropriate key prefixing
      #
      # @param key_prefix [Array<String>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String] The version to create mapping for
      # @return [void]
      def mapping(key_prefix:, value_prefix:, mapping:, version:)
        reference_mapping = from.mapping(version:, property:).dup
        value_key_prefix = mapping_value_key(value_prefix:)

        # Single field mapping
        if property && reference_mapping.size == 1 && !reference_mapping.keys.first.include?("/")
          reference_mapping = {
            (key_prefix + [name]).join("/") => value_key_prefix
          }
        else
          if value_key_prefix != "" && !value_key_prefix.end_with?("/")
            value_key_prefix = "#{value_key_prefix}/"
          end

          reference_mapping.transform_keys! { "#{(key_prefix + [name]).join("/")}/#{_1}" }
          reference_mapping.transform_values! { "#{value_key_prefix}#{_1}" }
        end

        mapping.merge!(reference_mapping)
      end

      private

      attr_reader :from, :property
    end
  end
end

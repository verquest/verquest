# frozen_string_literal: true

module Verquest
  module Properties
    # The Enum class represents a enum property with a list of possible values in a JSON schema.
    #
    # @example
    #   enum = Enum.new(name: "type", values: ["member", "admin"])
    class Enum < Base
      # Initialize a new Enum property
      #
      # @param name [String, Symbol] The name of the property
      # @param values [Array] The enum values for this property
      # @param required [Boolean, Array<Symbol>] Whether this property is required, or array of dependency names
      # @param nullable [Boolean] Whether this property can be null
      # @param map [String, nil] The mapping path for this property
      # @param schema_options [Hash] Additional JSON schema options for this property
      # @raise [ArgumentError] If attempting to map an enum to root without a name
      # @raise [ArgumentError] If values is empty
      # @raise [ArgumentError] If values are not unique
      # @raise [ArgumentError] If only one value is provided (should use const instead)
      def initialize(name:, values:, required: false, nullable: false, map: nil, **schema_options)
        raise ArgumentError, "You can not map enums to the root without a name" if map == "/"
        raise ArgumentError, "Values must not be empty" if values.empty?
        raise ArgumentError, "Values must be unique" if values.uniq.length != values.length
        raise ArgumentError, "Use const for a single value" if values.length == 1

        @name = name.to_s
        @values = nullable ? values | [nil] : values
        @required = required
        @nullable = nullable
        @map = map
        @schema_options = schema_options&.transform_keys(&:to_s)
      end

      # Generate JSON schema definition for this enum. Without a type in the schema options, the type is
      # inferred from the values, as the query coercer does.
      #
      # @return [Hash] The schema definition for this enum
      def to_schema
        {
          name => inferred_type.merge("enum" => values).merge(schema_options)
        }
      end

      # Create mapping for this enum property
      #
      # @param key_prefix [Array<String>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String, nil] The version to create mapping for
      # @return [void]
      def mapping(key_prefix:, value_prefix:, mapping:, version: nil)
        mapping[(key_prefix + [name]).join("/")] = mapping_value_key(value_prefix:)
      end

      private

      # @return [Hash] "type" (and "nullable" under OpenAPI 3.0) for the values, empty when a value has no JSON type
      def inferred_type
        return {} if schema_options.key?("type")

        types = values.compact.map { |value| Query::Coercer::JSON_TYPES[value.class] }
        return {} if types.empty? || types.include?(nil)

        types = types.uniq
        types.delete("integer") if types.include?("number")
        typed(types)
      end

      # OpenAPI 3.0 has no type arrays, so nullable is a keyword there and mixed values stay untyped
      def typed(types)
        if Verquest.configuration.json_schema_version == :openapi30
          return {} if types.size > 1

          nullable ? {"type" => types.first, "nullable" => true} : {"type" => types.first}
        else
          types += ["null"] if nullable
          {"type" => (types.size == 1) ? types.first : types}
        end
      end

      attr_reader :values, :schema_options
    end
  end
end

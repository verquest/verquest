# frozen_string_literal: true

module Verquest
  module Properties
    # The Enum class represents a enum property with a list of possible values in a JSON schema.
    #
    # The type is inferred from the values unless `type:` is given, and every value must fit it.
    #
    # @example
    #   enum = Enum.new(name: "type", values: ["member", "admin"])
    #   enum.to_schema # => {"type" => {"type" => "string", "enum" => ["member", "admin"]}}
    class Enum < Base
      # Ruby classes the values of each JSON type can have
      VALUE_CLASSES = {
        "string" => [::String],
        "integer" => [::Integer],
        "number" => [::Numeric],
        "boolean" => [::TrueClass, ::FalseClass],
        "object" => [::Hash]
      }.freeze

      # Classes of the JSON values that need no further check inside a Hash
      JSON_SCALARS = [::String, ::TrueClass, ::FalseClass, ::NilClass].freeze

      # Added to errors about Symbols
      SYMBOL_HINT = " (Symbols never match JSON values, use Strings)"

      # Initialize a new Enum property
      #
      # @param name [String, Symbol] The name of the property
      # @param values [Array] The enum values for this property
      # @param required [Boolean, Array<Symbol>] Whether this property is required, or array of dependency names
      # @param nullable [Boolean] Whether this property can be null
      # @param map [String, nil] The mapping path for this property
      # @param type [String, Symbol, Array<String, Symbol>, nil] The JSON type of the values, inferred from them when nil
      # @param schema_options [Hash] Additional JSON schema options for this property
      # @raise [ArgumentError] If attempting to map an enum to root without a name
      # @raise [ArgumentError] If values is not an Array, or is empty
      # @raise [ArgumentError] If values are not unique, comparing them as JSON (1 and 1.0 are the same)
      # @raise [ArgumentError] If only one value is provided (should use const instead)
      # @raise [ArgumentError] If values include nil without nullable, or a number that isn't finite
      # @raise [ArgumentError] If a value has no JSON type, the type is unknown, or a value isn't of the type
      # @raise [ArgumentError] If a Hash value has a key that isn't a String, or contains a value that isn't JSON
      def initialize(name:, values:, required: false, nullable: false, map: nil, type: nil, **schema_options)
        raise ArgumentError, "You can not map enums to the root without a name" if map == "/"

        check_values!(values, nullable)

        @name = name.to_s
        @values = nullable ? values | [nil] : values
        @types = type.nil? ? inferred_types : checked_types(type)
        @required = required
        @nullable = nullable
        @map = map
        @schema_options = schema_options.transform_keys(&:to_s).except("type")
      end

      # Generate JSON schema definition for this enum. Nullable adds "null" to the type.
      #
      # @return [Hash] The schema definition for this enum
      def to_schema
        {
          name => {"type" => schema_type, "enum" => values}.merge(schema_options)
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

      attr_reader :values, :types, :schema_options

      # @param values [Array] The given values
      # @param nullable [Boolean] Whether the enum can be null
      # @raise [ArgumentError] If the values are not an Array, empty, not JSON, not unique, a single value, or include nil
      #   without nullable
      def check_values!(values, nullable)
        raise ArgumentError, "Values must be an Array" unless values.is_a?(::Array)
        raise ArgumentError, "Values must not be empty" if values.empty?

        values.each { |value| check_json!(value, value) }
        raise ArgumentError, "Values must be unique" if values.uniq { |value| json_value(value) }.length != values.length
        raise ArgumentError, "Use const for a single value" if values.length == 1
        raise ArgumentError, "Values include nil, which needs nullable: true" if values.include?(nil) && !nullable
      end

      # Checks numbers and walks Hashes; top-level Arrays and other classes are left to the type check
      #
      # @param value [Object] An enum value, or a part of a Hash value
      # @param enum_value [Object] The enum value, for errors
      # @param nested [Boolean] Whether the value is inside a Hash
      # @raise [ArgumentError] If a number isn't finite, or a Hash value has a key or part that isn't JSON
      def check_json!(value, enum_value, nested: false)
        case value
        when ::Numeric then raise ArgumentError, "Enum values must be finite numbers" unless finite?(value)
        when ::Hash then value.each { |key, item| check_key!(key, enum_value) || check_json!(item, enum_value, nested: true) }
        when ::Array then value.each { |item| check_json!(item, enum_value, nested: true) } if nested
        when *JSON_SCALARS then nil
        else
          raise ArgumentError, "Enum value #{enum_value.inspect} contains #{value.inspect}, which is not a JSON value#{symbol_hint(value)}" if nested
        end
      end

      # @param key [Object] A key of a Hash value
      # @param enum_value [Object] The enum value, for errors
      # @return [nil]
      # @raise [ArgumentError] If the key isn't a String
      def check_key!(key, enum_value)
        return if key.is_a?(::String)

        raise ArgumentError, "Enum value #{enum_value.inspect} has key #{key.inspect}, which is not a String#{symbol_hint(key)}"
      end

      # @param value [Numeric] A number
      # @return [Boolean] Whether JSON can represent the number
      def finite?(value)
        value.real? && value.finite?
      end

      # @param value [Object] The value an error is about
      # @return [String, nil] The hint for a Symbol
      def symbol_hint(value)
        SYMBOL_HINT if value.is_a?(::Symbol)
      end

      # @return [String, Array<String>] The type, with "null" when nullable
      def schema_type
        all = nullable ? types | ["null"] : types
        (all.size == 1) ? all.first : all
      end

      # @return [Array<String>] The types of the non-nil values; integers next to other numerics are numbers
      def inferred_types
        found = values.compact.map { |value| json_type(value) }.uniq
        found.delete("integer") if found.include?("number")
        found
      end

      # VALUE_CLASSES lists "integer" before "number", so an Integer is an integer
      #
      # @param value [Object] A non-nil enum value
      # @return [String] The JSON type of the value
      # @raise [ArgumentError] If the value has no JSON type
      def json_type(value)
        type = VALUE_CLASSES.keys.find { |name| of_type?(value, name) }
        return type if type

        raise ArgumentError, "Enum value #{value.inspect} is not a String, Numeric, boolean or Hash#{symbol_hint(value)}"
      end

      # @param type [String, Symbol, Array<String, Symbol>] The given type
      # @return [Array<String>] The given types as strings
      # @raise [ArgumentError] If a type is unknown or a value isn't of the types
      def checked_types(type)
        given = Array(type).map(&:to_s).uniq
        if given.empty? || !given.all? { |name| VALUE_CLASSES.key?(name) }
          raise ArgumentError, "Unknown enum type #{type.inspect}, use one of #{VALUE_CLASSES.keys.join(", ")}"
        end

        invalid = values.compact.reject { |value| given.any? { |name| of_type?(value, name) } }
        raise ArgumentError, "Enum value #{invalid.first.inspect} is not of type #{given.join(" or ")}" unless invalid.empty?

        given
      end

      # @param value [Object] A non-nil enum value
      # @param name [String] A JSON type in VALUE_CLASSES
      # @return [Boolean] Whether the value is of the type
      def of_type?(value, name)
        VALUE_CLASSES.fetch(name).any? { |klass| value.is_a?(klass) }
      end

      # @param value [Object] An enum value, or a part of a Hash value
      # @return [Object] The value as JSON compares it: whole numbers as Integers, also inside Hashes and Arrays
      def json_value(value)
        case value
        when ::Hash then value.transform_values { |item| json_value(item) }
        when ::Array then value.map { |item| json_value(item) }
        when ::Numeric then (finite?(value) && value == value.to_i) ? value.to_i : value
        else value
        end
      end
    end
  end
end

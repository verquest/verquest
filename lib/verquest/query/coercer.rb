# frozen_string_literal: true

module Verquest
  module Query
    # Converts parsed query parameters to the types their schema expects
    #
    # Query strings carry only strings, so `"2"` has to become `2` and `"a,b"`
    # has to become `["a", "b"]` before the params are validated. The coercer
    # walks the version's validation schema next to the params. A value no rule
    # converts is left unchanged, so the validation reports it.
    #
    # @example
    #   schema = {"type" => "object", "properties" => {"page" => {"type" => "integer"}}}
    #   Verquest::Query::Coercer.new(schema:, explodes: {}).call({"page" => "2"})
    #   # => {"page" => 2}
    class Coercer
      # Returned by a rule that doesn't apply to a value
      NO_MATCH = ::Object.new.freeze

      # The JSON type of each class an enum or const value can have
      JSON_TYPES = {
        ::Integer => "integer",
        ::Float => "number",
        ::String => "string",
        ::TrueClass => "boolean",
        ::FalseClass => "boolean",
        ::NilClass => "null"
      }.freeze

      # Strings converted to an Integer
      INTEGER_PATTERN = /\A-?\d+\z/

      # Strings converted to an Integer or a Float
      NUMBER_PATTERN = /\A-?\d+(\.\d+)?\z/

      # Strings converted to a boolean
      BOOLEANS = {"true" => true, "false" => false}.freeze

      # @param schema [Hash] The version's validation schema
      # @param explodes [Hash{Array<String> => Boolean}] The explode value of each array property, by path
      def initialize(schema:, explodes:)
        @schema = schema
        @explodes = explodes
      end

      # Converts the params
      #
      # @param params [Hash] The parsed query parameters, with string or symbol keys
      # @return [Hash] A copy of the params with converted values
      def call(params)
        coerce_properties(params, schema, [])
      end

      private

      attr_reader :schema, :explodes

      # @return [Hash] A copy of the hash with each known property converted
      def coerce_properties(hash, object_schema, path)
        properties = object_schema.fetch("properties", {})
        additional = object_schema["additionalProperties"]

        hash.each_with_object(hash.dup) do |(key, value), result|
          property_schema = properties.fetch(key.to_s) { additional if additional.is_a?(Hash) }
          next unless property_schema

          coerced = coerce(value, property_schema, path + [key.to_s])
          result[key] = coerced unless coerced.equal?(NO_MATCH)
        end
      end

      # Tries the schema's types, then its anyOf and oneOf variants
      #
      # @return [Object] The converted value or NO_MATCH
      def coerce(value, value_schema, path)
        types(value_schema).each do |type|
          coerced = coerce_type(type, value, value_schema, path)
          return coerced unless coerced.equal?(NO_MATCH)
        end

        value_schema.values_at("anyOf", "oneOf").compact.flatten.each do |variant|
          coerced = coerce(value, variant, path)
          return coerced unless coerced.equal?(NO_MATCH)
        end

        NO_MATCH
      end

      # @return [Array<String>] The schema's types, inferred from enum and const values without a type
      def types(value_schema)
        if value_schema.key?("type")
          types = Array(value_schema["type"])
          value_schema["nullable"] ? [*types, "null"] : types
        elsif value_schema.key?("enum")
          value_schema["enum"].filter_map { |value| JSON_TYPES[value.class] }.uniq
        elsif value_schema.key?("const")
          [JSON_TYPES[value_schema["const"].class]].compact
        else
          []
        end
      end

      # @return [Object] The value converted to the type or NO_MATCH
      def coerce_type(type, value, value_schema, path)
        case type
        when "integer" then coerce_integer(value)
        when "number" then coerce_number(value)
        when "boolean" then coerce_boolean(value)
        when "null" then (value.nil? || value == "") ? nil : NO_MATCH
        when "string" then value.is_a?(::String) ? value : NO_MATCH
        when "array" then coerce_array(value, value_schema, path)
        when "object" then value.is_a?(::Hash) ? coerce_properties(value, value_schema, path) : NO_MATCH
        else NO_MATCH
        end
      end

      # @return [Integer, Object] The integer or NO_MATCH
      def coerce_integer(value)
        return value if value.is_a?(::Integer)
        return NO_MATCH unless value.is_a?(::String) && INTEGER_PATTERN.match?(value)

        Integer(value, 10)
      end

      # @return [Numeric, Object] The number or NO_MATCH
      def coerce_number(value)
        return value if value.is_a?(::Numeric)
        return NO_MATCH unless value.is_a?(::String) && NUMBER_PATTERN.match?(value)

        value.include?(".") ? Float(value) : Integer(value, 10)
      end

      # @return [Boolean, Object] The boolean or NO_MATCH
      def coerce_boolean(value)
        return value if value == true || value == false

        BOOLEANS.fetch(value, NO_MATCH)
      end

      # Splits a string by the array's explode value and converts each item;
      # an item no rule converts is kept as it is
      def coerce_array(value, array_schema, path)
        items = split(value, path)
        return items if items.equal?(NO_MATCH) || !array_schema.key?("items")

        items.map do |item|
          coerced = coerce(item, array_schema["items"], path)
          coerced.equal?(NO_MATCH) ? item : coerced
        end
      end

      # @return [Array, Object] The items of the value or NO_MATCH
      def split(value, path)
        return value if value.is_a?(::Array)
        return NO_MATCH unless value.is_a?(::String)

        explode?(path) ? [value] : value.split(",")
      end

      # @return [Boolean] Whether the array at the path is sent as repeated keys
      def explode?(path)
        explodes.fetch(path) { Verquest.configuration.query_array_explode }
      end
    end
  end
end

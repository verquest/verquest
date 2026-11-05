# frozen_string_literal: true

module Verquest
  module Query
    # Builds OpenAPI parameter objects from a query or path version's validation schema
    #
    # Each property becomes one `in: :query` (or `in: :path`) parameter. Keys are symbols,
    # including inside `schema`, because rswag reads them that way
    # (`param[:in]`, `param[:style]`, `param[:schema][:type]`).
    #
    # @example
    #   schema = {"type" => "object", "required" => [], "properties" => {"page" => {"type" => "integer"}}}
    #   Verquest::Query::Parameters.new(schema:, options: {}).call
    #   # => [{name: "page", in: :query, required: false, schema: {type: "integer"}}]
    class Parameters
      # Schema keys moved to the parameter itself
      DOCUMENTATION_KEYS = %w[description deprecated].freeze

      # @param schema [Hash] The version's validation schema
      # @param options [Hash{Array<String> => Hash}] The `explode:` and `examples:` of each property path
      # @param location [Symbol] `:query` or `:path`, written as `in:`
      def initialize(schema:, options:, location: :query)
        @schema = schema
        @options = options
        @location = location
      end

      # @return [Array<Hash>] The parameter objects, in property order
      def call
        required = schema.fetch("required", [])

        schema.fetch("properties", {}).map do |name, property_schema|
          parameter(name, property_schema, required: required.include?(name))
        end
      end

      private

      attr_reader :schema, :options, :location

      # @return [Hash] The parameter object of one property
      def parameter(name, property_schema, required:)
        {name:, in: location, required:}
          .merge(property_schema.slice(*DOCUMENTATION_KEYS).transform_keys(&:to_sym))
          .merge(serialization(name, property_schema))
          .merge(examples(name))
          .merge(schema: symbolize(property_schema.except(*DOCUMENTATION_KEYS)))
      end

      # @return [Hash] The style and explode of an array or object parameter
      def serialization(name, property_schema)
        types = [property_schema, *property_schema.fetch("anyOf", [])].flat_map { |variant| Array(variant["type"]) }

        if types.include?("object")
          {style: :deepObject, explode: true}
        elsif types.include?("array")
          {style: :form, explode: options.fetch([name], {}).fetch(:explode) { Verquest.configuration.query_array_explode }}
        else
          {}
        end
      end

      # @return [Hash] The named Example Objects of the parameter, if it has any
      def examples(name)
        examples = options.dig([name], :examples)
        examples ? {examples: symbolize(examples)} : {}
      end

      # @return [Object] The value with symbol keys in every hash
      def symbolize(value)
        case value
        when ::Hash then value.to_h { |key, child| [key.to_sym, symbolize(child)] }
        when ::Array then value.map { |child| symbolize(child) }
        else value
        end
      end
    end
  end
end

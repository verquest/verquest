# frozen_string_literal: true

module Verquest
  class Transformer
    # Rewrites `const` as a one-value `enum` in a schema
    #
    # Draft 4 and OpenAPI 3.0 have no `const`, so variants that differ only by
    # a const would all match during variant inference. A one-value `enum`
    # means the same and works in every JSON Schema version.
    #
    # @example
    #   ConstAsEnum.call({"properties" => {"const" => {"const" => "a"}}})
    #   # => {"properties" => {"const" => {"enum" => ["a"]}}}
    #
    # Internal to the transformer, not part of the public API.
    module ConstAsEnum
      # Keywords whose value is a map from names to schemas
      SCHEMA_MAPS = %w[properties patternProperties definitions $defs dependentSchemas].freeze

      # Keywords whose value is data, not a schema
      DATA_KEYWORDS = %w[enum default examples].freeze

      module_function

      # @param schema [Object] The schema, or a part of it
      # @return [Object] The schema with every `const` rewritten
      def call(schema)
        case schema
        when Hash then schema.to_h { |keyword, value| rewrite(keyword, value) }
        when Array then schema.map { |item| call(item) }
        else schema
        end
      end

      # @param keyword [String] The schema keyword
      # @param value [Object] Its value
      # @return [Array(String, Object)] The rewritten keyword and value
      def rewrite(keyword, value)
        return ["enum", [value]] if keyword == "const"
        return [keyword, value] if DATA_KEYWORDS.include?(keyword)
        return [keyword, value.transform_values { |subschema| call(subschema) }] if SCHEMA_MAPS.include?(keyword) && value.is_a?(Hash)

        [keyword, call(value)]
      end
    end
  end
end

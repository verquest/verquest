# frozen_string_literal: true

module Verquest
  # Rewrites a JSON Schema into OpenAPI 3.0 forms
  #
  # OpenAPI 3.0 has no "null" type and no type arrays. Properties write the JSON Schema forms, which validators
  # honour, so only documents are converted, when `json_schema_version` is `:openapi30`:
  # - "null" in a type array becomes `nullable: true`
  # - several types become an `anyOf` of single types, each nullable when the schema is
  # - an `anyOf` with a single null alternative becomes `nullable: true`, with an `allOf` around a `$ref`
  #   (OpenAPI 3.0 ignores keywords next to `$ref`) and `null` added to an `enum`
  #
  # Only schema positions are visited, so a property named "type" is never read as the keyword.
  #
  # @example
  #   Verquest::Openapi30.document({"type" => ["string", "null"]})
  #   # => {"type" => "string", "nullable" => true}
  module Openapi30
    # The null alternative of a nullable anyOf
    NULL_SCHEMA = {"type" => "null"}.freeze

    # Keywords whose value is a map from names to schemas
    SCHEMA_MAPS = %w[properties patternProperties dependentSchemas $defs definitions].freeze

    # Keywords whose value is a list of schemas
    SCHEMA_LISTS = %w[prefixItems anyOf oneOf allOf].freeze

    # Keywords whose value is a schema (`items` can also be a list)
    SCHEMAS = %w[items additionalProperties not if then else].freeze

    module_function

    # @param schema [Object] A schema; other values, such as `additionalProperties: false`, are returned as they are
    # @return [Object] A converted copy of the schema
    def document(schema)
      return schema unless schema.is_a?(::Hash)

      type_union(nullable_any_of(schema.to_h { |keyword, value| [keyword, child(keyword, value)] }))
    end

    # @param keyword [String] The schema keyword
    # @param value [Object] Its value
    # @return [Object] The value, with the schemas it holds converted
    def child(keyword, value)
      if SCHEMA_MAPS.include?(keyword) && value.is_a?(::Hash)
        value.transform_values { |schema| document(schema) }
      elsif (SCHEMA_LISTS.include?(keyword) || SCHEMAS.include?(keyword)) && value.is_a?(::Array)
        value.map { |schema| document(schema) }
      elsif SCHEMAS.include?(keyword)
        document(value)
      else
        value
      end
    end

    # OpenAPI 3.0 honours nullable only next to type, so each branch of a union carries it
    #
    # @param schema [Hash] A schema with converted children
    # @return [Hash] The schema without a type array
    def type_union(schema)
      types = schema["type"]
      return schema unless types.is_a?(::Array)

      others = types - ["null"]
      return schema if others.empty?

      nullable = types.include?("null") ? {"nullable" => true} : {}
      return schema.merge("type" => others.first).merge(nullable) if others.one?

      any_of(schema.except("type"), others.map { |type| {"type" => type}.merge(nullable) })
    end

    # @param schema [Hash] A schema without its type
    # @param variants [Array<Hash>] The single-type schemas
    # @return [Hash] The schema with the variants as an anyOf, next to an existing anyOf through allOf
    def any_of(schema, variants)
      return schema.merge("anyOf" => variants) unless schema.key?("anyOf")

      schema.except("anyOf").merge("allOf" => [*schema["allOf"], {"anyOf" => variants}, {"anyOf" => schema["anyOf"]}])
    end

    # @param schema [Hash] A schema with converted children
    # @return [Hash] The schema without a null alternative in its anyOf
    def nullable_any_of(schema)
      variants = schema["anyOf"]
      return schema unless variants.is_a?(::Array) && variants.include?(NULL_SCHEMA)

      others = variants - [NULL_SCHEMA]
      return schema if others.empty?

      siblings = schema.except("anyOf").merge("nullable" => true)
      others.one? ? nullable_alternative(others.first, siblings) : siblings.merge("anyOf" => others)
    end

    # OpenAPI 3.0 ignores keywords next to $ref, so a nullable $ref goes into an allOf
    #
    # @param alternative [Object] The only non-null alternative
    # @param siblings [Hash] The other keywords of the schema, with nullable
    # @return [Hash] The nullable schema
    def nullable_alternative(alternative, siblings)
      return siblings.merge("anyOf" => [alternative]) unless alternative.is_a?(::Hash)
      return {"allOf" => [alternative]}.merge(siblings) if alternative.key?("$ref")

      nullable_enum(alternative).merge(siblings)
    end

    # OpenAPI 3.0 needs null listed in an enum next to nullable
    #
    # @param schema [Hash] The only non-null alternative
    # @return [Hash] The alternative, with nil in its enum
    def nullable_enum(schema)
      schema.key?("enum") ? schema.merge("enum" => schema["enum"] | [nil]) : schema
    end

    private_class_method :child, :type_union, :any_of, :nullable_any_of, :nullable_alternative, :nullable_enum
  end
end

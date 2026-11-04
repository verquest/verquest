# frozen_string_literal: true

module Verquest
  module Properties
    class OneOf < Base
      # Builds a self-contained oneOf validation schema that keeps the discriminator
      #
      # OpenAPI validators (json_schemer's OpenAPI 3.0 and 3.1 dialects) select the
      # discriminated variant through each oneOf entry's `$ref`, so the variants move
      # into local definitions. The content-based identifier makes those `$ref`s resolve
      # against this schema wherever it is embedded, and identical content always gets
      # the same identifier. Other dialects ignore the discriminator and validate every variant.
      #
      # The identifier is set as both `$id` (draft 6 and later, OpenAPI 3.1) and `id`
      # (draft 4, OpenAPI 3.0), and the variants live under `definitions`, which every
      # dialect can reference. The output is the same whatever `json_schema_version` is.
      #
      # @example
      #   DiscriminatedSchema.new(definitions: {"dog" => dog_schema, "cat" => cat_schema}, discriminator: "type").to_h
      #   # => {
      #   #   "$id" => "https://verquest.local/one_of/3f1c9a0b2d4e5f67",
      #   #   "id" => "https://verquest.local/one_of/3f1c9a0b2d4e5f67",
      #   #   "definitions" => {"dog" => dog_schema, "cat" => cat_schema},
      #   #   "oneOf" => [{"$ref" => "#/definitions/dog"}, {"$ref" => "#/definitions/cat"}],
      #   #   "discriminator" => {"propertyName" => "type", "mapping" => {"dog" => "#/definitions/dog", "cat" => "#/definitions/cat"}}
      #   # }
      class DiscriminatedSchema
        # Base URI for the schema identifier
        ID_PREFIX = "https://verquest.local/one_of/"

        # Initialize a new DiscriminatedSchema
        #
        # @param definitions [Hash<String, Hash>] Variant name (discriminator value) => inline validation schema
        # @param discriminator [String] The discriminator property name
        def initialize(definitions:, discriminator:)
          @definitions = definitions
          @discriminator = discriminator
        end

        # Builds the validation schema
        #
        # @return [Hash] Schema with identifiers, definitions, oneOf refs, and discriminator
        def to_h
          {"$id" => id, "id" => id}.merge(body)
        end

        private

        # @!attribute [r] definitions
        #   @return [Hash<String, Hash>] Variant name => inline validation schema
        # @!attribute [r] discriminator
        #   @return [String] The discriminator property name
        attr_reader :definitions, :discriminator

        # The schema without the identifiers
        #
        # @return [Hash] Definitions, oneOf refs, and discriminator
        def body
          @body ||= {
            "definitions" => definitions,
            "oneOf" => refs.values.map { |ref| {"$ref" => ref} },
            "discriminator" => {"propertyName" => discriminator, "mapping" => refs}
          }
        end

        # Content-based identifier, so identical schemas share it
        #
        # `allow_nan` keeps schemas with infinite or NaN numbers (e.g. `maximum: Float::INFINITY`) hashable.
        #
        # @return [String] The identifier URI
        def id
          @id ||= "#{ID_PREFIX}#{Digest::SHA256.hexdigest(JSON.generate(body, allow_nan: true))[0, 16]}"
        end

        # Local `$ref` for each variant, keyed by variant name
        #
        # @return [Hash<String, String>] Variant name => `$ref` string
        def refs
          @refs ||= definitions.keys.to_h { |name| [name, "#/definitions/#{name}"] }
        end
      end
    end
  end
end

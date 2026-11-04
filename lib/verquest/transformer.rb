# frozen_string_literal: true

module Verquest
  # Transforms parameters from the external request structure to the internal one
  #
  # A version builds its transformer from its properties: each property adds
  # its full source and target paths to a Layout, and Plan groups the layout
  # into scopes (the params, the items of each collection that holds a oneOf,
  # and each oneOf variant). Transforming only applies those scopes. The
  # deprecated mapping constructor turns a mapping hash into a layout through
  # MappingLayout instead.
  #
  # @example Transforming a request's params
  #   OrderRequest.process(params, version: "2025-06")
  #   # or, without validation:
  #   OrderRequest.resolve("2025-06").transformer.call(params)
  #
  # The examples below show the mapping format with the mapping constructor,
  # which is deprecated and removed in 1.0.0.
  #
  # @example Basic transformation
  #   mapping = {
  #     "user/firstName" => "user/first_name",
  #     "user/lastName" => "user/last_name",
  #     "addresses[]/zip" => "addresses[]/postal_code"
  #   }
  #
  #   transformer = Verquest::Transformer.new(mapping: mapping)
  #   result = transformer.call({
  #     "user" => {"firstName" => "John", "lastName" => "Doe"},
  #     "addresses" => [{"zip" => "12345"}, {"zip" => "67890"}]
  #   })
  #
  #   # Result will be:
  #   # {
  #   #   "user" => {"first_name" => "John", "last_name" => "Doe"},
  #   #   "addresses" => [{"postal_code" => "12345"}, {"postal_code" => "67890"}]
  #   # }
  #
  # @example Discriminator-based transformation (oneOf)
  #   # For oneOf schemas with a discriminator, the mapping is keyed by discriminator value
  #   mapping = {
  #     "dog" => { "name" => "name", "bark" => "bark" },
  #     "cat" => { "name" => "name", "meow" => "meow" }
  #   }
  #
  #   transformer = Verquest::Transformer.new(mapping: mapping, discriminator: "type")
  #   result = transformer.call({ "type" => "dog", "name" => "Rex", "bark" => true })
  #   # Uses the "dog" mapping
  #
  # @example Schema-based variant inference (oneOf without discriminator)
  #   # When no discriminator is present, the transformer infers the variant by validating
  #   # against each schema and selecting the one that matches
  #   mapping = {
  #     "_variant_schemas" => {
  #       "with_id" => { "type" => "object", "required" => ["id"], ... },
  #       "without_id" => { "type" => "object", ... }
  #     },
  #     "with_id" => { "id" => "id", "name" => "name" },
  #     "without_id" => { "name" => "name" }
  #   }
  #
  #   transformer = Verquest::Transformer.new(mapping: mapping)
  #   result = transformer.call({ "id" => "123", "name" => "Test" })
  #   # Infers "with_id" variant and uses its mapping
  class Transformer
    # Mapping keys that hold oneOf metadata, not property paths or variant names
    METADATA_KEYS = %w[_discriminator _variant_schemas _variant_path _nullable _nullable_path _nullable_target_path _oneOfs].freeze

    # Creates a new Transformer
    #
    # @param layout [Layout, nil] The full paths of the request; versions pass it, it is not public API
    # @param mapping [Hash, nil] Deprecated: a mapping hash, read when no layout is given
    # @param discriminator [String, Symbol, nil] Deprecated: the discriminator of a root-level oneOf in the mapping
    # @return [Transformer] A new transformer instance
    # @raise [ArgumentError] If neither layout nor mapping is given
    def initialize(layout: nil, mapping: nil, discriminator: nil)
      raise ArgumentError, "Transformer.new needs layout: (or the deprecated mapping:)" unless layout || mapping

      if layout.nil?
        warn "Verquest::Transformer.new(mapping:) is deprecated and will be removed in 1.0.0. " \
          "Use MyRequest.process, or MyRequest.resolve(version).transformer.", category: :deprecated, uplevel: 1
        layout = MappingLayout.call(mapping, discriminator:)
      end

      @root = Plan.new(layout).root
      freeze
    end

    # Transforms input parameters according to the provided mapping
    #
    # @param params [Hash] The input parameters to transform
    # @return [Hash] The transformed parameters with string keys
    # @raise [Verquest::MappingError] If a oneOf matches no variant or more than one
    def call(params)
      root.call(params)
    end

    private

    # @!attribute [r] root
    #   @return [Scope] The mapping of the params
    attr_reader :root
  end
end

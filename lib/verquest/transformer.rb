# frozen_string_literal: true

module Verquest
  # Transforms parameters based on path mappings
  #
  # The Transformer class handles the conversion of parameter structures based on
  # a mapping of source paths to target paths. It supports deep nested structures,
  # array notations, and complex path expressions using slash notation.
  #
  # At initialization, the mapping is turned into a Plan: the source and
  # target pairs and oneOfs of the params, and of the items of each
  # collection that holds a oneOf. Transforming only applies that plan.
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

    # Creates a new Transformer with the specified mapping
    #
    # @param mapping [Hash] A hash where keys are source paths and values are target paths,
    #   or for discriminator-based schemas, keys are discriminator values and values are mapping hashes
    # @param discriminator [String, Symbol, nil] The discriminator of a root-level oneOf
    # @return [Transformer] A new transformer instance
    def initialize(mapping:, discriminator: nil)
      @root = Plan.new(mapping, discriminator:).root
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

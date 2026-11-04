# frozen_string_literal: true

module Verquest
  class Transformer
    # One oneOf in a mapping, with the variant mapping each input selects
    #
    # Paths are relative to the scope the oneOf is resolved in: the params, or
    # a collection item.
    #
    # @example
    #   one_of = OneOf.new(
    #     path: Path.new("pet"),
    #     discriminator: Path.new("pet/type"),
    #     variants: {"dog" => [[Path.new("pet/bark"), Path.new("pet/bark")]]}
    #   )
    #   one_of.mapping_for({"pet" => {"type" => "dog", "bark" => true}}) # => the "dog" pairs
    class OneOf
      # Initialize a new OneOf
      #
      # @param path [Path] The oneOf property, empty for a oneOf at the scope root
      # @param variants [Hash<String, Array<Array(Path, Path)>>] Source and target pairs by variant name
      # @param discriminator [Path, nil] The discriminator property
      # @param variant_schemas [Hash<String, Hash>, nil] Validation schemas by variant name, without a discriminator
      # @param null_target [Path, nil] Where a null oneOf goes, defaults to the oneOf path
      def initialize(path:, variants:, discriminator: nil, variant_schemas: nil, null_target: nil)
        @path = path
        @variants = variants
        @discriminator = discriminator
        @schemers = variant_schemas&.transform_values { |schema| JSONSchemer.schema(schema) }
        @null_mapping = path.to_s.empty? ? [] : [[path, null_target || path]]
        freeze
      end

      # Returns the source and target pairs the data selects
      #
      # An absent oneOf maps nothing, and a null one maps only the null.
      #
      # @param data [Object] The scope data holding the oneOf
      # @return [Array<Array(Path, Path)>] The source and target pairs
      # @raise [Verquest::MappingError] If no variant or more than one variant matches
      def mapping_for(data)
        value = path.to_s.empty? ? data : path.extract(data)
        return [] if value.equal?(Path::NOT_FOUND)
        return null_mapping if value.nil?

        variants.fetch(discriminator ? discriminated_variant(data) : inferred_variant(value))
      end

      private

      # @!attribute [r] path
      #   @return [Path] The oneOf property
      # @!attribute [r] variants
      #   @return [Hash<String, Array<Array(Path, Path)>>] Source and target pairs by variant name
      # @!attribute [r] discriminator
      #   @return [Path, nil] The discriminator property
      # @!attribute [r] schemers
      #   @return [Hash<String, JSONSchemer::Schema>, nil] Schemers by variant name
      # @!attribute [r] null_mapping
      #   @return [Array<Array(Path, Path)>] The pairs for a null oneOf
      attr_reader :path, :variants, :discriminator, :schemers, :null_mapping

      # @param data [Object] The scope data holding the oneOf
      # @return [String] The variant named by the discriminator value
      # @raise [Verquest::MappingError] If the value is missing or unknown
      def discriminated_variant(data)
        value = discriminator.extract(data)
        raise Verquest::MappingError, "Missing discriminator \"#{discriminator}\" for oneOf." if value.nil? || value.equal?(Path::NOT_FOUND)
        return value.to_s if variants.key?(value.to_s)

        raise Verquest::MappingError, "Unknown discriminator value \"#{value}\" for oneOf. No matching variant found."
      end

      # @param value [Object] The oneOf value
      # @return [String] The only variant whose schema the value matches
      # @raise [Verquest::MappingError] If no variant or more than one variant matches
      def inferred_variant(value)
        # Two matches are enough to know the match is ambiguous
        matches = schemers.each_key.lazy.select { |name| schemers[name].valid?(value) }.first(2)
        return matches.first if matches.one?

        raise Verquest::MappingError, "No matching schema found for oneOf. Input does not match any of the defined schemas." if matches.empty?

        raise Verquest::MappingError, "Ambiguous oneOf match. Input matches multiple schemas: #{matches.join(", ")}. " \
          "Consider adding a discriminator or making schemas mutually exclusive."
      end
    end
  end
end

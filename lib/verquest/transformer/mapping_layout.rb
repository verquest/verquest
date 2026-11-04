# frozen_string_literal: true

module Verquest
  class Transformer
    # Turns a mapping hash into a Layout
    #
    # A mapping is flat, holds a single oneOf (variant mappings that repeat
    # the other properties, plus metadata keys), or several oneOfs (`_oneOfs`).
    # The oneOf paths and collection targets the hash doesn't hold are worked
    # out from its paths. Only the deprecated `Transformer.new(mapping:)` uses
    # it; versions build their layout from their properties.
    #
    # @deprecated Removed in 1.0.0 together with `Transformer.new(mapping:)`
    #
    # Internal to the transformer, not part of the public API.
    class MappingLayout
      # Builds the layout of a mapping
      #
      # @param mapping [Hash] The mapping in any of its formats
      # @param discriminator [String, Symbol, nil] The discriminator of a root-level oneOf
      # @return [Layout] The layout
      def self.call(mapping, discriminator: nil)
        new(mapping, discriminator&.to_s).layout
      end

      private_class_method :new

      # @!attribute [r] layout
      #   @return [Layout] The layout of the mapping
      attr_reader :layout

      # @param mapping [Hash] The mapping in any of its formats
      # @param discriminator [String, nil] The discriminator of a root-level oneOf
      def initialize(mapping, discriminator)
        @layout = Layout.new
        pairs, one_ofs = split(mapping, discriminator)
        pairs.each { |source, target| layout.add_pair(source, target) }
        one_ofs.each { |one_of| layout.add_one_of(one_of) }
        one_ofs.each { |one_of| add_collections(one_of.path, one_ofs, pairs) }
      end

      private

      # Splits a mapping into its source and target pairs and its oneOfs
      #
      # @param mapping [Hash] The mapping in any of its formats
      # @param discriminator [String, nil] The discriminator of a root-level oneOf
      # @return [Array(Hash, Array<Layout::OneOfLayout>)] The pairs and the oneOfs
      def split(mapping, discriminator)
        pairs = mapping.reject { |key, value| METADATA_KEYS.include?(key) || value.is_a?(Hash) }
        return [pairs, mapping["_oneOfs"].map { |one_of| one_of_layout(one_of) }] if mapping.key?("_oneOfs")
        return [pairs, []] unless discriminator || mapping.key?("_discriminator") || mapping.key?("_variant_schemas")

        single = mapping.except(*pairs.keys)
        single = single.merge("_discriminator" => discriminator) if discriminator
        one_of = one_of_layout(single)
        [pairs.merge(shared_pairs(single, one_of.path)), [one_of]]
      end

      # Builds the layout of a oneOf mapping
      #
      # @param mapping [Hash] The oneOf mapping, with metadata keys
      # @return [Layout::OneOfLayout] The oneOf layout
      def one_of_layout(mapping)
        variants = variant_mappings(mapping)
        path = one_of_path(mapping, variants)
        discriminator = mapping["_discriminator"]

        Layout::OneOfLayout.new(
          path:,
          discriminator:,
          variants: variants.transform_values { |pairs| variant_layout(pairs, path) },
          variant_schemas: (mapping["_variant_schemas"] unless discriminator),
          null_target: mapping["_nullable_target_path"]
        )
      end

      # Builds the layout of a variant from its pairs inside the oneOf
      #
      # @param pairs [Hash] The variant mapping
      # @param path [String] The oneOf source path
      # @return [Layout] The variant layout
      def variant_layout(pairs, path)
        layout.variant.tap do |variant|
          # A Hash target is a oneOf nested in the variant, which the mapping formats can't express
          pairs.each { |source, target| variant.add_pair(source, target) if target.is_a?(String) && inside?(source, path) }
        end
      end

      # Returns the variant mappings of a oneOf mapping
      #
      # @param mapping [Hash] The oneOf mapping
      # @return [Hash<String, Hash>] Source and target pairs by variant name
      def variant_mappings(mapping)
        mapping.select { |key, value| !METADATA_KEYS.include?(key) && value.is_a?(Hash) }
      end

      # Returns the pairs a single-oneOf mapping repeats in every variant
      #
      # @param mapping [Hash] The oneOf mapping
      # @param path [String] The oneOf source path
      # @return [Hash] The pairs outside the oneOf property
      def shared_pairs(mapping, path)
        return {} if path.empty?

        variant_mappings(mapping).values.first.reject { |source, _| inside?(source, path) }
      end

      # Returns the source path of a oneOf property
      #
      # Taken from the discriminator, the variant path or the nullable path.
      # Otherwise, the oneOf is at the root, or at the items of the collection
      # all its properties are in.
      #
      # @param mapping [Hash] The oneOf mapping
      # @param variants [Hash<String, Hash>] Source and target pairs by variant name
      # @return [String] The source path, empty for a root-level oneOf
      def one_of_path(mapping, variants)
        return mapping["_discriminator"].rpartition("/").first if mapping["_discriminator"]
        return mapping["_variant_path"] || mapping["_nullable_path"] if mapping.key?("_variant_path") || mapping.key?("_nullable_path")

        sources = variants.values.flat_map(&:keys)
        collection = sources.first.include?("[]") ? "#{sources.first.split("[]").first}[]" : ""
        (!collection.empty? && sources.all? { |source| inside?(source, collection) }) ? collection : ""
      end

      # Adds the collections a oneOf path enters, with their target paths
      #
      # @param path [String] The oneOf source path
      # @param one_ofs [Array<Layout::OneOfLayout>] All oneOfs
      # @param pairs [Hash] The source and target pairs outside the oneOfs
      # @return [void]
      def add_collections(path, one_ofs, pairs)
        1.upto(path.scan("[]").size) do |depth|
          prefix = "#{path.split("[]").first(depth).join("[]")}[]"
          layout.add_collection(prefix, target_collection(prefix, one_ofs, pairs)) unless layout.collections.key?(prefix)
        end
      end

      # Returns the target path of a collection, which differs when it uses map:
      #
      # Found from a property mapped inside the collection, so a property moved
      # out of it with map: "/..." doesn't count.
      #
      # @param prefix [String] The collection source path, ending with "[]"
      # @param one_ofs [Array<Layout::OneOfLayout>] All oneOfs
      # @param pairs [Hash] The source and target pairs outside the oneOfs
      # @return [String] The collection target path, ending with "[]"
      def target_collection(prefix, one_ofs, pairs)
        depth = prefix.scan("[]").size
        candidates = one_ofs.flat_map { |one_of| one_of.variants.values.flat_map { |variant| variant.pairs.to_a } } + pairs.to_a
        _, target = candidates.find { |source, target_path| inside?(source, prefix) && target_path.scan("[]/").size >= depth }
        target ? "#{target.split("[]/").first(depth).join("[]/")}[]" : prefix
      end

      # Checks whether a path is inside another one
      #
      # @param path [String] The path
      # @param prefix [String] The containing path, empty for the root
      # @return [Boolean] True if the path is below the prefix
      def inside?(path, prefix)
        prefix.empty? || path.start_with?("#{prefix}/")
      end
    end
  end
end

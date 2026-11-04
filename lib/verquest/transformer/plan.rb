# frozen_string_literal: true

module Verquest
  class Transformer
    # Turns a mapping, in any of its formats, into the scopes the transformer applies
    #
    # A mapping is flat, holds a single oneOf (variant mappings that repeat
    # the other properties, plus metadata keys), or several oneOfs (`_oneOfs`).
    # The plan has one scope for the params and one for the items of each
    # collection that holds a oneOf, since every item can select a different
    # variant. Paths in a collection scope are relative to the item.
    #
    # @example
    #   plan = Plan.new({"id" => "id", "_discriminator" => "pet/type", "dog" => {...}, "cat" => {...}})
    #   plan.root        # => Scope with the "id" pair and the "pet" oneOf
    #   plan.collections # => []
    class Plan
      # A oneOf mapping with the oneOf source path and its variant mappings
      #
      # @!attribute [r] mapping
      #   @return [Hash] The oneOf mapping, with metadata keys
      # @!attribute [r] path
      #   @return [String] The oneOf source path, empty for a root-level oneOf
      # @!attribute [r] variants
      #   @return [Hash<String, Hash>] Source and target pairs by variant name
      OneOfMapping = Data.define(:mapping, :path, :variants)

      # The collection prefixes the paths of a scope are relative to
      #
      # @!attribute [r] source
      #   @return [String] The source collection path ending with "[]", empty for the params
      # @!attribute [r] target
      #   @return [String] The target collection path ending with "[]", empty for the params
      Prefix = Data.define(:source, :target)

      # The prefix of the params scope
      ROOT = Prefix.new(source: "", target: "")

      private_constant :OneOfMapping, :Prefix, :ROOT

      # @!attribute [r] root
      #   @return [Scope] The mapping of the params
      # @!attribute [r] collections
      #   @return [Array<Collection>] The collections transformed item by item
      attr_reader :root, :collections

      # Builds the plan
      #
      # @param mapping [Hash] The mapping in any of its formats
      # @param discriminator [String, Symbol, nil] The discriminator of a root-level oneOf
      def initialize(mapping, discriminator: nil)
        @paths = {}
        one_ofs, pairs = split(mapping, discriminator&.to_s)
        by_collection = one_ofs.group_by { |one_of| collection_of(one_of.path) }
        prefixes = by_collection.keys - [""]
        root_pairs = pairs.reject { |source, _| prefixes.any? { |prefix| inside?(source, prefix) } }

        @root = build_scope(root_pairs, by_collection.fetch("", []), ROOT)
        @collections = prefixes.map { |prefix| build_collection(prefix, by_collection[prefix], pairs) }.freeze
      end

      private

      # Splits a mapping into its oneOf mappings and the other source and target pairs
      #
      # @param mapping [Hash] The mapping in any of its formats
      # @param discriminator [String, nil] The discriminator of a root-level oneOf
      # @return [Array(Array<OneOfMapping>, Hash)] The oneOf mappings and the other pairs
      def split(mapping, discriminator)
        pairs = mapping.reject { |key, value| METADATA_KEYS.include?(key) || value.is_a?(Hash) }
        return [mapping["_oneOfs"].map { |one_of| one_of_mapping(one_of) }, pairs] if mapping.key?("_oneOfs")
        return [[], pairs] unless discriminator || mapping.key?("_discriminator") || mapping.key?("_variant_schemas")

        single = mapping.except(*pairs.keys)
        single = single.merge("_discriminator" => discriminator) if discriminator
        one_of = one_of_mapping(single)
        [[one_of], pairs.merge(shared_pairs(one_of))]
      end

      # Builds the plan for a collection whose items hold a oneOf
      #
      # @param prefix [String] The collection source path, ending with "[]"
      # @param one_ofs [Array<OneOfMapping>] The oneOfs in the collection items
      # @param pairs [Hash] The source and target pairs outside the oneOfs
      # @return [Collection] The collection plan
      def build_collection(prefix, one_ofs, pairs)
        item_prefix = Prefix.new(source: prefix, target: target_collection(prefix, one_ofs, pairs))

        Collection.new(
          source: path(item_prefix.source.delete_suffix("[]")),
          target: path(item_prefix.target.delete_suffix("[]")),
          scope: build_scope(pairs.select { |source, _| inside?(source, prefix) }, one_ofs, item_prefix)
        )
      end

      # Builds a scope, with paths relative to the prefix
      #
      # @param pairs [Hash] The source and target pairs
      # @param one_ofs [Array<OneOfMapping>] The oneOfs
      # @param prefix [Prefix] The collection prefixes, ROOT for the params
      # @return [Scope] The scope
      def build_scope(pairs, one_ofs, prefix)
        Scope.new(pairs: relative_pairs(pairs, prefix), one_ofs: one_ofs.map { |one_of| build_one_of(one_of, prefix) }.freeze)
      end

      # Builds a oneOf, with paths relative to the prefix
      #
      # @param one_of [OneOfMapping] The oneOf mapping
      # @param prefix [Prefix] The collection prefixes, ROOT for the params
      # @return [OneOf] The oneOf
      def build_one_of(one_of, prefix)
        discriminator = one_of.mapping["_discriminator"]
        null_target = one_of.mapping["_nullable_target_path"]

        OneOf.new(
          path: path(relative(one_of.path, prefix.source)),
          variants: one_of.variants.transform_values { |pairs| relative_pairs(pairs.select { |source, _| inside?(source, one_of.path) }, prefix) }.freeze,
          discriminator: discriminator && path(relative(discriminator, prefix.source)),
          variant_schemas: (one_of.mapping["_variant_schemas"] unless discriminator),
          null_target: null_target && path(relative(null_target, prefix.target))
        )
      end

      # Wraps a oneOf mapping with its source path and variant mappings
      #
      # @param mapping [Hash] The oneOf mapping
      # @return [OneOfMapping] The wrapped mapping
      def one_of_mapping(mapping)
        variants = mapping.select { |key, value| !METADATA_KEYS.include?(key) && value.is_a?(Hash) }
        OneOfMapping.new(mapping:, path: one_of_path(mapping, variants), variants:)
      end

      # Returns the pairs a single-oneOf mapping repeats in every variant
      #
      # @param one_of [OneOfMapping] The oneOf mapping
      # @return [Hash] The pairs outside the oneOf property
      def shared_pairs(one_of)
        return {} if one_of.path.empty?

        one_of.variants.values.first.reject { |source, _| inside?(source, one_of.path) }
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
        collection = collection_of(sources.first)
        (!collection.empty? && sources.all? { |source| inside?(source, collection) }) ? collection : ""
      end

      # Returns the collection a path starts in
      #
      # @param path [String] The source path
      # @return [String] The collection path ending with "[]", empty outside a collection
      def collection_of(path)
        path.include?("[]") ? "#{path.split("[]").first}[]" : ""
      end

      # Returns the target path of a collection, which differs when it uses map:
      #
      # Found from a property mapped inside the collection, so a property moved
      # out of it with map: "/..." doesn't count.
      #
      # @param prefix [String] The collection source path, ending with "[]"
      # @param one_ofs [Array<OneOfMapping>] The oneOfs in the collection items
      # @param pairs [Hash] The source and target pairs outside the oneOfs
      # @return [String] The collection target path, ending with "[]"
      def target_collection(prefix, one_ofs, pairs)
        candidates = one_ofs.flat_map { |one_of| one_of.variants.values.flat_map(&:to_a) } + pairs.to_a
        _, target = candidates.find { |source, target_path| inside?(source, prefix) && target_path.include?("[]/") }
        target ? "#{target.split("[]/").first}[]" : prefix
      end

      # Converts source and target pairs to paths relative to the prefix
      #
      # @param pairs [Hash] Source and target pairs
      # @param prefix [Prefix] The collection prefixes, ROOT for the params
      # @return [Array<Array(Path, Path)>] The relative pairs
      def relative_pairs(pairs, prefix)
        pairs.map { |source, target| [path(relative(source, prefix.source)), path(relative(target, prefix.target))].freeze }.freeze
      end

      # Checks whether a path is inside another one
      #
      # @param path [String] The path
      # @param prefix [String] The containing path, empty for the root
      # @return [Boolean] True if the path is below the prefix
      def inside?(path, prefix)
        prefix.empty? || path.start_with?("#{prefix}/")
      end

      # Removes a prefix from a path
      #
      # @param path [String] The path
      # @param prefix [String] The prefix, empty for none
      # @return [String] The path below the prefix, empty for the prefix itself
      def relative(path, prefix)
        return "" if path == prefix

        prefix.empty? ? path : path.delete_prefix("#{prefix}/")
      end

      # Returns a parsed path, shared between the pairs that use it
      #
      # @param path [String] The slash-separated path
      # @return [Path] The parsed path
      def path(path)
        @paths[path.to_s] ||= Path.new(path.to_s)
      end
    end
  end
end

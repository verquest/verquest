# frozen_string_literal: true

module Verquest
  class Transformer
    # Turns a mapping, in any of its formats, into the scopes the transformer applies
    #
    # A mapping is flat, holds a single oneOf (variant mappings that repeat
    # the other properties, plus metadata keys), or several oneOfs (`_oneOfs`).
    # The plan is a scope for the params, with a nested scope for the items
    # of each collection that holds a oneOf, since every item can select a
    # different variant. Paths in a collection scope are relative to the item.
    #
    # @example
    #   plan = Plan.new({"id" => "id", "_discriminator" => "pet/type", "dog" => {...}, "cat" => {...}})
    #   plan.root # => Scope with the "id" pair and the "pet" oneOf
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
      attr_reader :root

      # Builds the plan
      #
      # @param mapping [Hash] The mapping in any of its formats
      # @param discriminator [String, Symbol, nil] The discriminator of a root-level oneOf
      # @raise [Verquest::MappingError] If map: moves a oneOf variant property out of its collection item
      def initialize(mapping, discriminator: nil)
        @paths = {}
        one_ofs, pairs = split(mapping, discriminator&.to_s)
        @root = build_scope(pairs, one_ofs, ROOT)
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

      # Builds a scope, with paths relative to the prefix
      #
      # The oneOfs inside a collection of this scope go to a nested scope for
      # that collection's items, with the pairs mapped into those items. A pair
      # moved out of the items with map: "/..." stays here.
      #
      # @param pairs [Hash] The source and target pairs in this scope
      # @param one_ofs [Array<OneOfMapping>] The oneOfs in this scope
      # @param prefix [Prefix] The collection prefixes, ROOT for the params
      # @return [Scope] The scope
      def build_scope(pairs, one_ofs, prefix)
        by_collection = one_ofs.group_by { |one_of| collection_of(one_of.path, prefix.source) }
        item_prefixes = (by_collection.keys - [""]).map do |source|
          Prefix.new(source:, target: target_collection(source, by_collection[source], pairs))
        end
        item_pairs = item_prefixes.to_h do |item_prefix|
          [item_prefix, pairs.select { |source, target| inside?(source, item_prefix.source) && inside?(target, item_prefix.target) }]
        end

        Scope.new(
          pairs: relative_pairs(pairs.reject { |source, _| item_pairs.each_value.any? { |inner| inner.key?(source) } }, prefix),
          one_ofs: by_collection.fetch("", []).map { |one_of| build_one_of(one_of, prefix) }.freeze,
          collections: item_prefixes.map { |item_prefix| build_collection(item_prefix, by_collection[item_prefix.source], item_pairs[item_prefix], prefix) }.freeze
        )
      end

      # Builds a collection whose items hold a oneOf
      #
      # @param item_prefix [Prefix] The collection prefixes, ending with "[]"
      # @param one_ofs [Array<OneOfMapping>] The oneOfs in the collection items
      # @param pairs [Hash] The source and target pairs mapped into the items
      # @param prefix [Prefix] The prefixes of the parent scope
      # @return [Collection] The collection
      def build_collection(item_prefix, one_ofs, pairs, prefix)
        Collection.new(
          source: path(relative(item_prefix.source.delete_suffix("[]"), prefix.source)),
          target: path(relative(item_prefix.target.delete_suffix("[]"), prefix.target)),
          scope: build_scope(pairs, one_ofs, item_prefix)
        )
      end

      # Builds a oneOf, with paths relative to the prefix
      #
      # @param one_of [OneOfMapping] The oneOf mapping
      # @param prefix [Prefix] The collection prefixes, ROOT for the params
      # @return [OneOf] The oneOf
      # @raise [Verquest::MappingError] If map: moves a variant property out of the collection item
      def build_one_of(one_of, prefix)
        check_variant_targets(one_of, prefix)
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

      # Rejects variant properties moved out of the collection item
      #
      # Each item selects its own variant, so its properties can only be
      # mapped inside the item.
      #
      # @param one_of [OneOfMapping] The oneOf mapping
      # @param prefix [Prefix] The collection prefixes, ROOT for the params
      # @return [void]
      # @raise [Verquest::MappingError] If a variant property is mapped out of the item
      def check_variant_targets(one_of, prefix)
        one_of.variants.each_value do |pairs|
          source, target = pairs.find { |_, target_path| !inside?(target_path, prefix.target) }
          raise MappingError, "map: can't move a oneOf variant property out of its collection item (#{source} => #{target})" if source
        end
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
        collection = collection_of(sources.first, "")
        (!collection.empty? && sources.all? { |source| inside?(source, collection) }) ? collection : ""
      end

      # Returns the first collection a path enters below a scope
      #
      # @param path [String] The source path
      # @param scope_source [String] The source prefix of the scope, empty for the params
      # @return [String] The collection path ending with "[]", empty when the path enters none
      def collection_of(path, scope_source)
        below = relative(path, scope_source)
        return "" unless below.include?("[]")

        collection = "#{below.split("[]").first}[]"
        scope_source.empty? ? collection : "#{scope_source}/#{collection}"
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
        depth = prefix.scan("[]").size
        candidates = one_ofs.flat_map { |one_of| one_of.variants.values.flat_map(&:to_a) } + pairs.to_a
        _, target = candidates.find { |source, target_path| inside?(source, prefix) && target_path.scan("[]/").size >= depth }
        target ? "#{target.split("[]/").first(depth).join("[]/")}[]" : prefix
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

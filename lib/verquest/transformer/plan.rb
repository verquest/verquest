# frozen_string_literal: true

module Verquest
  class Transformer
    # Groups a Layout into the scopes the transformer applies
    #
    # The plan is a scope for the params, with a nested scope for the items
    # of each collection that holds a oneOf, since every item can select a
    # different variant. Paths in a collection scope are relative to the item.
    # A oneOf variant is a scope with the same prefixes as the scope holding
    # the oneOf.
    #
    # @example
    #   plan = Plan.new(layout)
    #   plan.root # => Scope with the params pairs, oneOfs and collections
    #
    # Internal to the transformer, not part of the public API.
    class Plan
      # The collection prefixes the paths of a scope are relative to
      #
      # @!attribute [r] source
      #   @return [String] The source collection path ending with "[]", empty for the params
      # @!attribute [r] target
      #   @return [String] The target collection path ending with "[]", empty for the params
      Prefix = Data.define(:source, :target)

      # The prefix of the params scope
      ROOT = Prefix.new(source: "", target: "")

      private_constant :Prefix, :ROOT

      # @!attribute [r] root
      #   @return [Scope] The mapping of the params
      attr_reader :root

      # Builds the plan
      #
      # @param layout [Layout] The full paths of the request. Each layout must list every collection a oneOf path in it enters.
      # @raise [Verquest::MappingError] If map: moves a oneOf variant property out of its collection item
      def initialize(layout)
        @paths = {}
        @root = build_scope(layout.pairs, layout.one_ofs, ROOT, layout.collections)
      end

      private

      # Returns the target path of a collection
      #
      # @param collections [Hash<String, String>] Target path by source path of each collection
      # @param source [String] The collection source path, ending with "[]"
      # @return [String] The collection target path, ending with "[]"
      # @raise [ArgumentError] If the layout doesn't list the collection
      def collection_target(collections, source)
        collections.fetch(source) { raise ArgumentError, "The layout doesn't list the collection #{source}" }
      end

      # Builds a scope, with paths relative to the prefix
      #
      # The oneOfs inside a collection of this scope go to a nested scope for
      # that collection's items, with the pairs mapped into those items. A pair
      # moved out of the items with map: "/..." stays here.
      #
      # @param pairs [Hash] The source and target pairs in this scope
      # @param one_ofs [Array<Layout::OneOfLayout>] The oneOfs in this scope
      # @param prefix [Prefix] The collection prefixes, ROOT for the params
      # @param collections [Hash<String, String>] Target path by source path of the collections this scope sees
      # @return [Scope] The scope
      def build_scope(pairs, one_ofs, prefix, collections)
        by_collection = one_ofs.group_by { |one_of| collection_of(one_of.path, prefix.source) }
        item_prefixes = (by_collection.keys - [""]).map { |source| Prefix.new(source:, target: collection_target(collections, source)) }
        item_pairs = item_prefixes.to_h do |item_prefix|
          [item_prefix, pairs.select { |source, target| inside?(source, item_prefix.source) && inside?(target, item_prefix.target) }]
        end

        Scope.new(
          pairs: relative_pairs(pairs.reject { |source, _| item_pairs.each_value.any? { |inner| inner.key?(source) } }, prefix),
          one_ofs: by_collection.fetch("", []).map { |one_of| build_one_of(one_of, prefix) }.freeze,
          collections: item_prefixes.map { |item_prefix| build_collection(item_prefix, by_collection[item_prefix.source], item_pairs[item_prefix], prefix, collections) }.freeze
        )
      end

      # Builds a collection whose items hold a oneOf
      #
      # @param item_prefix [Prefix] The collection prefixes, ending with "[]"
      # @param one_ofs [Array<Layout::OneOfLayout>] The oneOfs in the collection items
      # @param pairs [Hash] The source and target pairs mapped into the items
      # @param prefix [Prefix] The prefixes of the parent scope
      # @param collections [Hash<String, String>] Target path by source path of the collections the parent scope sees
      # @return [Collection] The collection
      def build_collection(item_prefix, one_ofs, pairs, prefix, collections)
        Collection.new(
          source: path(relative(item_prefix.source.delete_suffix("[]"), prefix.source)),
          target: path(relative(item_prefix.target.delete_suffix("[]"), prefix.target)),
          scope: build_scope(pairs, one_ofs, item_prefix, collections)
        )
      end

      # Builds a oneOf, with paths relative to the prefix
      #
      # @param one_of [Layout::OneOfLayout] The oneOf layout
      # @param prefix [Prefix] The collection prefixes, ROOT for the params
      # @return [OneOf] The oneOf
      # @raise [Verquest::MappingError] If map: moves a variant property out of the collection item
      def build_one_of(one_of, prefix)
        check_variant_targets(one_of, prefix)

        OneOf.new(
          path: path(relative(one_of.path, prefix.source)),
          variants: one_of.variants.transform_values { |variant| build_scope(variant.pairs, variant.one_ofs, prefix, variant.collections) }.freeze,
          discriminator: one_of.discriminator && path(relative(one_of.discriminator, prefix.source)),
          variant_schemas: one_of.variant_schemas,
          null_target: one_of.null_target && path(relative(one_of.null_target, prefix.target))
        )
      end

      # Rejects variant properties moved out of the collection item
      #
      # Each item selects its own variant, so its properties can only be
      # mapped inside the item.
      #
      # @param one_of [Layout::OneOfLayout] The oneOf layout
      # @param prefix [Prefix] The collection prefixes, ROOT for the params
      # @return [void]
      # @raise [Verquest::MappingError] If a variant property is mapped out of the item
      def check_variant_targets(one_of, prefix)
        one_of.variants.each_value do |variant|
          source, target = variant.pairs.find { |_, target_path| !inside?(target_path, prefix.target) }
          raise MappingError, "map: can't move a oneOf variant property out of its collection item (#{source} => #{target})" if source
        end
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

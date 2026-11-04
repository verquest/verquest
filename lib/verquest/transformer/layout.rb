# frozen_string_literal: true

module Verquest
  class Transformer
    # The source and target paths of a request, before they are grouped into scopes
    #
    # Properties add themselves with full paths from the params root
    # (Properties::Base#layout), and Plan groups them into the scopes the
    # transformer applies. A oneOf variant gets its own layout, so it can hold
    # oneOfs and collections too. Its paths are full paths as well, like the
    # parent's. Each variant gets a copy of its parent's collections: Plan looks
    # up a collection's target by its source path, and same-named collections
    # in different variants can have different targets.
    #
    # A layout is filled while a version is prepared, then only read; the
    # hashes and arrays its readers return are not meant to be changed.
    #
    # @example
    #   layout = Layout.new
    #   layout.add_pair("user/firstName", "user/first_name")
    #   layout.add_collection("items[]", "lines[]")
    #
    # Internal to the transformer, not part of the public API.
    class Layout
      # A oneOf with full paths
      #
      # The paths are Strings; Plan turns them into Paths relative to the
      # scope that holds the oneOf. The variant layouts hold full paths too.
      #
      # @!attribute [r] path
      #   @return [String] The oneOf source path, empty for a root-level oneOf
      # @!attribute [r] discriminator
      #   @return [String, nil] The discriminator source path
      # @!attribute [r] variants
      #   @return [Hash<String, Layout>] The layout of each variant by name
      # @!attribute [r] variant_schemas
      #   @return [Hash<String, Hash>, nil] Validation schemas by variant name, without a discriminator
      # @!attribute [r] null_target
      #   @return [String, nil] Where a null oneOf goes, nil for its source path
      OneOfLayout = Data.define(:path, :discriminator, :variants, :variant_schemas, :null_target)

      # @!attribute [r] pairs
      #   @return [Hash<String, String>] Target path by source path
      # @!attribute [r] one_ofs
      #   @return [Array<OneOfLayout>] The oneOfs
      # @!attribute [r] collections
      #   @return [Hash<String, String>] Target path by source path of each collection, both ending with "[]"
      attr_reader :pairs, :one_ofs, :collections

      # @param collections [Hash<String, String>] The collections, shared with the parent layout
      def initialize(collections: {})
        @pairs = {}
        @one_ofs = []
        @collections = collections
      end

      # @param source [String] The source path
      # @param target [String] The target path
      # @return [void]
      def add_pair(source, target)
        pairs[source] = target
      end

      # @param one_of [OneOfLayout] The oneOf
      # @return [void]
      def add_one_of(one_of)
        one_ofs << one_of
      end

      # @param source [String] The collection source path, ending with "[]"
      # @param target [String] The collection target path, ending with "[]"
      # @return [void]
      def add_collection(source, target)
        collections[source] = target
      end

      # @return [Layout] An empty layout for a oneOf variant, with a copy of the collections
      def variant
        Layout.new(collections: collections.dup)
      end
    end
  end
end

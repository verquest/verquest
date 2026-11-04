# frozen_string_literal: true

module Verquest
  # Transforms parameters based on path mappings
  #
  # The Transformer class handles the conversion of parameter structures based on
  # a mapping of source paths to target paths. It supports deep nested structures,
  # array notations, and complex path expressions using slash notation.
  #
  # The mapping comes in one of three formats: flat, a single oneOf (variant
  # mappings that include the other properties, plus metadata keys), or
  # several oneOfs (`_oneOfs`). At initialization, each format is turned into
  # the same plan: source and target pairs plus oneOfs for the params, and the
  # same for the items of each collection that holds a oneOf.
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

    # Source and target pairs and the oneOfs that add more of them
    #
    # @!attribute [r] base
    #   @return [Array<Array(Path, Path)>] The pairs mapped for any input
    # @!attribute [r] one_ofs
    #   @return [Array<OneOf>] The oneOfs resolved for each input
    Scope = Data.define(:base, :one_ofs)

    # A collection whose items are transformed one by one, because they hold a oneOf
    #
    # @!attribute [r] source
    #   @return [Path] The collection in the params
    # @!attribute [r] target
    #   @return [Path] The collection in the result
    # @!attribute [r] scope
    #   @return [Scope] The mapping of each item, with item-level paths
    Collection = Data.define(:source, :target, :scope)

    private_constant :Scope, :Collection

    # Creates a new Transformer with the specified mapping
    #
    # @param mapping [Hash] A hash where keys are source paths and values are target paths,
    #   or for discriminator-based schemas, keys are discriminator values and values are mapping hashes
    # @param discriminator [String, Symbol, nil] The discriminator of a root-level oneOf
    # @return [Transformer] A new transformer instance
    def initialize(mapping:, discriminator: nil)
      @paths = {}
      one_of_mappings, base = split(mapping, discriminator&.to_s)
      build_plan(one_of_mappings.map { |one_of_mapping| [one_of_mapping, one_of_path(one_of_mapping)] }, base)
      @paths = nil
      freeze
    end

    # Transforms input parameters according to the provided mapping
    #
    # @param params [Hash] The input parameters to transform
    # @return [Hash] The transformed parameters with string keys
    # @raise [Verquest::MappingError] If a oneOf matches no variant or more than one
    def call(params)
      collections.each_with_object(apply(root, params)) do |collection, result|
        items = collection.source.extract(params, nulls: true)
        next if items.equal?(Path::NOT_FOUND)

        collection.target.set(result, items.is_a?(Array) ? items.map { |item| apply(collection.scope, item) } : items)
      end
    end

    private

    # @!attribute [r] root
    #   @return [Scope] The mapping of the params
    # @!attribute [r] collections
    #   @return [Array<Collection>] The collections transformed item by item
    attr_reader :root, :collections

    # Applies a scope to data
    #
    # When a source path's parent is explicitly null, the corresponding target
    # path is set to null in the result instead of being omitted.
    #
    # @param scope [Scope] The scope mapping
    # @param data [Object] The params or a collection item
    # @return [Hash] The transformed data
    def apply(scope, data)
      pairs = scope.base + scope.one_ofs.flat_map { |one_of| one_of.mapping_for(data) }
      pairs.each_with_object({}) do |(source, target), result|
        value = source.extract(data, nulls: true)
        target.set(result, value) unless value.equal?(Path::NOT_FOUND)
      end
    end

    # Splits a mapping into its oneOf mappings and the other source and target pairs
    #
    # @param mapping [Hash] The mapping in any of the three formats
    # @param discriminator [String, nil] The discriminator of a root-level oneOf
    # @return [Array(Array<Hash>, Hash)] The oneOf mappings and the other pairs
    def split(mapping, discriminator)
      pairs = mapping.reject { |key, value| METADATA_KEYS.include?(key) || value.is_a?(Hash) }
      return [mapping["_oneOfs"], pairs] if mapping.key?("_oneOfs")
      return [[], pairs] unless discriminator || mapping.key?("_discriminator") || mapping.key?("_variant_schemas")

      one_of_mapping = mapping.except(*pairs.keys)
      one_of_mapping = one_of_mapping.merge("_discriminator" => discriminator) if discriminator
      [[one_of_mapping], pairs.merge(shared_pairs(one_of_mapping))]
    end

    # Returns the pairs a single-oneOf mapping repeats in every variant
    #
    # @param one_of_mapping [Hash] The oneOf mapping
    # @return [Hash] The pairs outside the oneOf property
    def shared_pairs(one_of_mapping)
      path = one_of_path(one_of_mapping)
      return {} if path.empty?

      variant_mappings(one_of_mapping).values.first.reject { |source, _| inside?(source, path) }
    end

    # Builds the scopes for the params and for each collection with a oneOf
    #
    # @param one_ofs [Array<Array(Hash, String)>] Each oneOf mapping with its source path
    # @param base [Hash] The other source and target pairs
    # @return [void]
    def build_plan(one_ofs, base)
      by_collection = one_ofs.group_by { |(_, path)| path.include?("[]") ? "#{path.split("[]").first}[]" : "" }
      prefixes = by_collection.keys - [""]

      @root = build_scope(base.reject { |source, _| prefixes.any? { |prefix| inside?(source, prefix) } }, by_collection.fetch("", []), "", "")
      @collections = prefixes.map { |prefix| build_collection(prefix, by_collection[prefix], base) }.freeze
    end

    # Builds the plan for a collection whose items hold a oneOf
    #
    # @param prefix [String] The collection source path, ending with "[]"
    # @param one_ofs [Array<Array(Hash, String)>] The collection oneOf mappings with their source paths
    # @param base [Hash] The source and target pairs outside the oneOfs
    # @return [Collection] The collection plan
    def build_collection(prefix, one_ofs, base)
      target_prefix = target_collection_prefix(prefix, one_ofs, base)
      item_base = base.select { |source, _| inside?(source, prefix) }

      Collection.new(
        source: path(prefix.delete_suffix("[]")),
        target: path(target_prefix.delete_suffix("[]")),
        scope: build_scope(item_base, one_ofs, prefix, target_prefix)
      )
    end

    # Builds a scope, with paths relative to the given prefixes
    #
    # @param base [Hash] The source and target pairs
    # @param one_ofs [Array<Array(Hash, String)>] The oneOf mappings with their source paths
    # @param source_prefix [String] The source collection prefix, empty for the params
    # @param target_prefix [String] The target collection prefix, empty for the params
    # @return [Scope] The scope
    def build_scope(base, one_ofs, source_prefix, target_prefix)
      Scope.new(
        base: relative_pairs(base, source_prefix, target_prefix),
        one_ofs: one_ofs.map { |(one_of_mapping, one_of_path)| build_one_of(one_of_mapping, one_of_path, source_prefix, target_prefix) }.freeze
      )
    end

    # Builds a oneOf, with paths relative to the given prefixes
    #
    # @param one_of_mapping [Hash] The oneOf mapping
    # @param one_of_path [String] The oneOf source path
    # @param source_prefix [String] The source collection prefix, empty for the params
    # @param target_prefix [String] The target collection prefix, empty for the params
    # @return [OneOf] The oneOf
    def build_one_of(one_of_mapping, one_of_path, source_prefix, target_prefix)
      discriminator = one_of_mapping["_discriminator"]
      null_target = one_of_mapping["_nullable_target_path"]

      OneOf.new(
        path: path(relative(one_of_path, source_prefix)),
        variants: variant_mappings(one_of_mapping).transform_values do |pairs|
          relative_pairs(pairs.select { |source, _| inside?(source, one_of_path) }, source_prefix, target_prefix)
        end,
        discriminator: discriminator && path(relative(discriminator, source_prefix)),
        variant_schemas: (one_of_mapping["_variant_schemas"] unless discriminator),
        null_target: null_target && path(relative(null_target, target_prefix))
      )
    end

    # Returns the source path of a oneOf property
    #
    # Taken from the discriminator, the variant path or the nullable path. Otherwise, the oneOf
    # is at the root, or at the items of the collection all its properties are in.
    #
    # @param one_of_mapping [Hash] The oneOf mapping
    # @return [String] The source path, empty for a root-level oneOf
    def one_of_path(one_of_mapping)
      return one_of_mapping["_discriminator"].rpartition("/").first if one_of_mapping["_discriminator"]
      return one_of_mapping["_variant_path"] || one_of_mapping["_nullable_path"] if one_of_mapping.key?("_variant_path") || one_of_mapping.key?("_nullable_path")

      sources = variant_mappings(one_of_mapping).values.flat_map(&:keys)
      collection = "#{sources.first.split("[]").first}[]"
      (sources.first.include?("[]") && sources.all? { |source| inside?(source, collection) }) ? collection : ""
    end

    # Returns the target path of a collection, which differs when it uses map:
    #
    # Found from a property mapped inside the collection, so a property moved
    # out of it with map: "/..." doesn't count.
    #
    # @param prefix [String] The collection source path, ending with "[]"
    # @param one_ofs [Array<Array(Hash, String)>] The collection oneOf mappings with their source paths
    # @param base [Hash] The source and target pairs outside the oneOfs
    # @return [String] The collection target path, ending with "[]"
    def target_collection_prefix(prefix, one_ofs, base)
      pairs = one_ofs.flat_map { |(one_of_mapping, _)| variant_mappings(one_of_mapping).values.flat_map(&:to_a) } + base.to_a
      _, target = pairs.find { |source, target_path| inside?(source, prefix) && target_path.include?("[]/") }
      target ? "#{target.split("[]/").first}[]" : prefix
    end

    # Returns the variant mappings of a oneOf mapping
    #
    # @param one_of_mapping [Hash] The oneOf mapping
    # @return [Hash<String, Hash>] Source and target pairs by variant name
    def variant_mappings(one_of_mapping)
      one_of_mapping.select { |key, value| !METADATA_KEYS.include?(key) && value.is_a?(Hash) }
    end

    # Converts source and target pairs to paths relative to the given prefixes
    #
    # @param pairs [Hash] Source and target pairs
    # @param source_prefix [String] The source collection prefix, empty for the params
    # @param target_prefix [String] The target collection prefix, empty for the params
    # @return [Array<Array(Path, Path)>] The relative pairs
    def relative_pairs(pairs, source_prefix, target_prefix)
      pairs.map { |source, target| [path(relative(source, source_prefix)), path(relative(target, target_prefix))].freeze }.freeze
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

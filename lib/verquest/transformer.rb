# frozen_string_literal: true

module Verquest
  # Transforms parameters based on path mappings
  #
  # The Transformer class handles the conversion of parameter structures based on
  # a mapping of source paths to target paths. It supports deep nested structures,
  # array notations, and complex path expressions using slash notation.
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
  #     user: {
  #       firstName: "John",
  #       lastName: "Doe"
  #     },
  #     addresses: [
  #       { zip: "12345" },
  #       { zip: "67890" }
  #     ]
  #   })
  #
  #   # Result will be:
  #   # {
  #   #   user: {
  #   #     first_name: "John",
  #   #     last_name: "Doe"
  #   #   },
  #   #   addresses: [
  #   #     { postal_code: "12345" },
  #   #     { postal_code: "67890" }
  #   #   ]
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
    # Creates a new Transformer with the specified mapping
    #
    # @param mapping [Hash] A hash where keys are source paths and values are target paths,
    #   or for discriminator-based schemas, keys are discriminator values and values are mapping hashes
    # @param discriminator [String, nil] The property name used to discriminate between schemas (for oneOf)
    # @return [Transformer] A new transformer instance
    def initialize(mapping:, discriminator: nil)
      @mapping = mapping
      @discriminator = discriminator
      @path_cache = {} # Cache for parsed paths to improve performance
      @schemer_cache = {} # Cache for JSONSchemer instances
      precompile_paths # Prepare cache during initialization
      precompile_schemers # Prepare schemer cache during initialization
    end

    # Transforms input parameters according to the provided mapping
    #
    # @param params [Hash] The input parameters to transform
    # @return [Hash] The transformed parameters with symbol keys
    def call(params)
      # Handle collection with oneOf (per-item variant inference)
      if collection_with_one_of?
        return transform_collection_with_one_of(params)
      end

      active_mapping = resolve_mapping(params)
      return {} if active_mapping.nil?

      result = {}

      active_mapping.each do |source_path, target_path|
        # Extract value using the source path
        value = extract_value(params, parse_path(source_path.to_s))
        next if value.nil?

        # Set the extracted value at the target path
        set_value(result, parse_path(target_path.to_s), value)
      end

      result
    end

    private

    # @!attribute [r] mapping
    #   @return [Hash] The source-to-target path mapping
    # @!attribute [r] path_cache
    #   @return [Hash] Cache for parsed paths
    # @!attribute [r] discriminator
    #   @return [String, nil] The discriminator property name for oneOf schemas
    # @!attribute [r] schemer_cache
    #   @return [Hash] Cache for JSONSchemer instances
    attr_reader :mapping, :path_cache, :discriminator, :schemer_cache

    # Resolves which mapping to use based on the discriminator value or schema inference
    #
    # For nested oneOf, the discriminator can be a path (e.g., "payment/method")
    # and the mapping contains a "_discriminator" key with the path.
    #
    # When no discriminator is present but "_variant_schemas" exists, the variant
    # is inferred by validating the input against each schema.
    #
    # For multiple oneOf, the mapping contains a "_oneOfs" array and base properties.
    #
    # @param params [Hash] The input parameters
    # @return [Hash, nil] The resolved mapping to use for transformation
    def resolve_mapping(params)
      # Handle multiple oneOf
      return resolve_multiple_one_of(params) if multiple_one_of?

      disc_path = effective_discriminator
      return mapping unless disc_path || variant_schemas

      if disc_path
        resolve_by_discriminator(params, disc_path)
      else
        resolve_by_schema_inference(params)
      end
    end

    # Checks if this mapping has multiple oneOf definitions
    #
    # @return [Boolean] True if _oneOfs array is present
    def multiple_one_of?
      mapping.key?("_oneOfs")
    end

    # Resolves mapping for multiple oneOf by resolving each independently and combining
    #
    # @param params [Hash] The input parameters
    # @return [Hash] Combined mapping from base properties + all resolved variants
    def resolve_multiple_one_of(params)
      result = {}

      # Add base (non-oneOf) properties
      mapping.each do |key, value|
        next if key == "_oneOfs"
        next if key.start_with?("_")

        result[key] = value
      end

      # Resolve each oneOf and add its variant mapping
      mapping["_oneOfs"].each do |one_of_mapping|
        variant_mapping = resolve_single_one_of(params, one_of_mapping)
        result.merge!(variant_mapping) if variant_mapping
      end

      result
    end

    # Resolves a single oneOf from the _oneOfs array
    #
    # @param params [Hash] The input parameters
    # @param one_of_mapping [Hash] The mapping for this oneOf
    # @return [Hash, nil] The resolved variant mapping
    def resolve_single_one_of(params, one_of_mapping)
      disc_path = one_of_mapping["_discriminator"]

      if disc_path
        resolve_one_of_by_discriminator(params, one_of_mapping, disc_path)
      elsif one_of_mapping["_variant_schemas"]
        resolve_one_of_by_schema_inference(params, one_of_mapping)
      end
    end

    # Resolves a oneOf variant using discriminator
    #
    # @param params [Hash] The input parameters
    # @param one_of_mapping [Hash] The mapping for this oneOf
    # @param disc_path [String] The discriminator path
    # @return [Hash, nil] The resolved variant mapping
    def resolve_one_of_by_discriminator(params, one_of_mapping, disc_path)
      discriminator_value = extract_value(params, parse_path(disc_path))
      return nil if discriminator_value.nil?

      one_of_mapping[discriminator_value.to_s] || one_of_mapping[discriminator_value]
    end

    # Resolves a oneOf variant by schema inference
    #
    # @param params [Hash] The input parameters
    # @param one_of_mapping [Hash] The mapping for this oneOf
    # @return [Hash, nil] The resolved variant mapping
    # @raise [Verquest::MappingError] If no schema matches or multiple schemas match
    def resolve_one_of_by_schema_inference(params, one_of_mapping)
      variant_path = one_of_mapping["_variant_path"]
      variant_schemas = one_of_mapping["_variant_schemas"]

      data_to_validate = if variant_path
        extracted = extract_value(params, parse_path(variant_path))
        # If the oneOf field is not present, skip it (optional field)
        return nil if extracted.nil?

        extracted
      else
        params
      end

      matching_variants = find_matching_variants_for(data_to_validate, variant_schemas)

      case matching_variants.size
      when 0
        raise Verquest::MappingError, "No matching schema found for oneOf. " \
          "Input does not match any of the defined schemas."
      when 1
        one_of_mapping[matching_variants.first]
      else
        raise Verquest::MappingError, "Ambiguous oneOf match. " \
          "Input matches multiple schemas: #{matching_variants.join(", ")}. " \
          "Consider adding a discriminator or making schemas mutually exclusive."
      end
    end

    # Finds matching variants for given data and schemas
    #
    # @param data [Hash] The data to validate
    # @param variant_schemas [Hash] The variant schemas to validate against
    # @return [Array<String>] Names of matching variants
    def find_matching_variants_for(data, variant_schemas)
      matches = []
      variant_schemas.each do |name, schema|
        schemer = JSONSchemer.schema(schema)
        matches << name if schemer.valid?(data)
        break if matches.size > 1 # Early exit on ambiguity
      end
      matches
    end

    # Resolves variant mapping using discriminator value
    #
    # @param params [Hash] The input parameters
    # @param disc_path [String] The discriminator path
    # @return [Hash, nil] The resolved mapping
    def resolve_by_discriminator(params, disc_path)
      discriminator_value = extract_value(params, parse_path(disc_path))
      return nil if discriminator_value.nil?

      mapping[discriminator_value.to_s] || mapping[discriminator_value]
    end

    # Resolves variant mapping by validating against each schema
    #
    # @param params [Hash] The input parameters
    # @return [Hash, nil] The resolved mapping
    # @raise [Verquest::MappingError] If no schema matches or multiple schemas match
    def resolve_by_schema_inference(params)
      data_to_validate = extract_variant_data(params)
      matching_variants = find_matching_variants(data_to_validate)

      case matching_variants.size
      when 0
        raise Verquest::MappingError, "No matching schema found for oneOf. " \
          "Input does not match any of the defined schemas."
      when 1
        mapping[matching_variants.first]
      else
        raise Verquest::MappingError, "Ambiguous oneOf match. " \
          "Input matches multiple schemas: #{matching_variants.join(", ")}. " \
          "Consider adding a discriminator or making schemas mutually exclusive."
      end
    end

    # Extracts the data portion to validate for nested oneOf
    #
    # @param params [Hash] The full input parameters
    # @return [Hash] The data to validate against variant schemas
    def extract_variant_data(params)
      variant_path = mapping["_variant_path"]
      return params unless variant_path

      extract_value(params, parse_path(variant_path)) || {}
    end

    # Finds all variants whose schema validates the input
    #
    # Uses cached JSONSchemer instances for performance and exits early
    # if more than one match is found (ambiguous case).
    #
    # @param data [Hash] The data to validate
    # @return [Array<String>] Names of matching variants
    def find_matching_variants(data)
      matches = []
      schemer_cache.each do |name, schemer|
        matches << name if schemer.valid?(data)
        break if matches.size > 1 # Early exit on ambiguity
      end
      matches
    end

    # Returns the variant schemas for schema-based inference
    #
    # @return [Hash, nil] The variant schemas hash or nil if not present
    def variant_schemas
      mapping["_variant_schemas"]
    end

    # Checks if this is a collection with oneOf (requires per-item variant resolution)
    #
    # @return [Boolean] True if mapping contains array paths with variant mappings
    def collection_with_one_of?
      # Check for discriminator-less oneOf with variant schemas
      has_schema_based = variant_schemas &&
        variant_mappings.any? { |_, m| m.keys.any? { |path| path.include?("[]") } }

      # Check for discriminator-based oneOf in collection (discriminator path contains [])
      has_discriminator_based = effective_discriminator&.include?("[]") &&
        variant_mappings.any? { |_, m| m.keys.any? { |path| path.include?("[]") } }

      has_schema_based || has_discriminator_based
    end

    # Checks if this uses a discriminator for collection items
    #
    # @return [Boolean] True if discriminator is inside a collection
    def discriminator_in_collection?
      effective_discriminator&.include?("[]")
    end

    # Returns only the variant mapping entries (excludes metadata keys)
    #
    # @return [Hash] Hash of variant name => mapping pairs
    def variant_mappings
      mapping.select { |key, value| !key.start_with?("_") && value.is_a?(Hash) }
    end

    # Transforms a collection where each item may match different oneOf variants
    #
    # @param params [Hash] The input parameters to transform
    # @return [Hash] The transformed parameters
    def transform_collection_with_one_of(params)
      # Find the collection path from the variant mappings
      sample_variant = mapping.find { |k, v| !k.start_with?("_") && v.is_a?(Hash) }
      return {} unless sample_variant

      sample_path = sample_variant[1].keys.first
      collection_path = sample_path.split("[]").first

      result = {}

      # Transform non-collection properties first (root-level properties outside the oneOf)
      transform_non_collection_properties(params, result)

      # Extract the collection
      collection = extract_value(params, parse_path(collection_path))
      return result unless collection.is_a?(Array)

      # Transform each item in the collection
      transformed_items = collection.map do |item|
        transform_collection_item(item, collection_path)
      end

      # Set the transformed collection in the result
      set_value(result, parse_path(target_collection_path(collection_path)), transformed_items)

      result
    end

    # Transforms non-collection properties from the mapping
    #
    # These are root-level properties that exist outside the variant-keyed mappings.
    #
    # @param params [Hash] The input parameters
    # @param result [Hash] The result hash to update
    # @return [void]
    def transform_non_collection_properties(params, result)
      mapping.each do |key, value|
        # Skip metadata keys and variant mappings (which are Hashes)
        next if key.start_with?("_")
        next if value.is_a?(Hash)

        # This is a simple key => value mapping for a root-level property
        extracted = extract_value(params, parse_path(key))
        next if extracted.nil?

        set_value(result, parse_path(value), extracted)
      end
    end

    # Returns the target collection path, accounting for any mapping
    #
    # @param source_path [String] The source collection path
    # @return [String] The target collection path
    def target_collection_path(source_path)
      # Check if there's a custom mapping for the collection path
      # by looking at the target paths in any variant
      sample_variant = mapping.find { |k, v| !k.start_with?("_") && v.is_a?(Hash) }
      return source_path unless sample_variant

      sample_target = sample_variant[1].values.first
      sample_target.split("[]").first
    end

    # Transforms a single item from a collection using variant resolution
    #
    # Uses discriminator if present, otherwise infers variant by schema validation.
    #
    # @param item [Hash] The item to transform
    # @param collection_path [String] The path to the collection
    # @return [Hash] The transformed item
    def transform_collection_item(item, collection_path)
      if discriminator_in_collection?
        transform_item_with_discriminator(item, collection_path)
      else
        transform_item_with_schema_inference(item, collection_path)
      end
    end

    # Transforms an item using discriminator-based variant resolution
    #
    # @param item [Hash] The item to transform
    # @param collection_path [String] The path to the collection
    # @return [Hash] The transformed item
    def transform_item_with_discriminator(item, collection_path)
      # Extract discriminator field name from the path (e.g., "pets[]/type" -> "type")
      disc_field = effective_discriminator.split("/").last
      disc_value = item[disc_field]

      return {} if disc_value.nil?

      variant_name = disc_value.to_s
      variant_mapping = mapping[variant_name]
      return {} unless variant_mapping

      item_mapping = extract_item_mapping(variant_name, collection_path)
      transform_item_with_mapping(item, item_mapping)
    end

    # Transforms an item using schema-based variant inference
    #
    # @param item [Hash] The item to transform
    # @param collection_path [String] The path to the collection
    # @return [Hash] The transformed item
    def transform_item_with_schema_inference(item, collection_path)
      # When there's a variant_path, validate just that nested portion
      data_to_validate = extract_item_variant_data(item)
      matching_variants = find_matching_variants(data_to_validate)

      case matching_variants.size
      when 0
        raise Verquest::MappingError, "No matching schema found for oneOf. " \
          "Input does not match any of the defined schemas."
      when 1
        variant_name = matching_variants.first
        item_mapping = extract_item_mapping(variant_name, collection_path)
        transform_item_with_mapping(item, item_mapping)
      else
        raise Verquest::MappingError, "Ambiguous oneOf match. " \
          "Input matches multiple schemas: #{matching_variants.join(", ")}. " \
          "Consider adding a discriminator or making schemas mutually exclusive."
      end
    end

    # Extracts the variant data from a collection item for schema validation
    #
    # @param item [Hash] The collection item
    # @return [Hash] The data to validate against variant schemas
    def extract_item_variant_data(item)
      variant_path = mapping["_variant_path"]
      return item unless variant_path

      extract_value(item, parse_path(variant_path)) || {}
    end

    # Extracts the item-level mapping from a variant mapping
    #
    # Converts paths like "items[]/id" => "items[]/id" to "id" => "id"
    # Also includes non-variant collection properties (e.g., fields alongside oneOf).
    #
    # @param variant_name [String] The variant name
    # @param collection_path [String] The collection path prefix
    # @return [Hash] The item-level mapping
    def extract_item_mapping(variant_name, collection_path)
      variant_mapping = mapping[variant_name]
      prefix = "#{collection_path}[]/"

      item_map = {}

      # Include non-variant properties from the collection (e.g., entry_id alongside oneOf)
      mapping.each do |source, target|
        next if source.start_with?("_")
        next if target.is_a?(Hash) # Skip variant mappings

        if source.start_with?(prefix)
          item_source = source.delete_prefix(prefix)
          item_target = target.start_with?(prefix) ? target.delete_prefix(prefix) : target
          item_map[item_source] = item_target
        end
      end

      # Include variant-specific properties
      variant_mapping.each do |source, target|
        if source.start_with?(prefix)
          item_source = source.delete_prefix(prefix)
          item_target = target.start_with?(prefix) ? target.delete_prefix(prefix) : target
          item_map[item_source] = item_target
        end
      end

      item_map
    end

    # Transforms an item using a specific mapping
    #
    # @param item [Hash] The item to transform
    # @param item_mapping [Hash] The mapping to use
    # @return [Hash] The transformed item
    def transform_item_with_mapping(item, item_mapping)
      result = {}

      item_mapping.each do |source_path, target_path|
        value = extract_value(item, parse_path(source_path))
        next if value.nil?

        set_value(result, parse_path(target_path), value)
      end

      result
    end

    # Precompiles all paths from the mapping to improve performance
    # This is called during initialization to prepare the cache
    #
    # @return [void]
    def precompile_paths
      if multiple_one_of?
        precompile_multiple_one_of_paths
      elsif effective_discriminator || variant_schemas
        parse_path(effective_discriminator) if effective_discriminator
        parse_path(mapping["_variant_path"]) if mapping["_variant_path"]
        precompile_variant_mappings
      else
        precompile_flat_mapping
      end
    end

    # Precompiles paths for multiple oneOf mappings
    #
    # @return [void]
    def precompile_multiple_one_of_paths
      # Precompile base property paths
      mapping.each do |key, value|
        next if key == "_oneOfs"
        next if key.start_with?("_")

        parse_path(key.to_s)
        parse_path(value.to_s)
      end

      # Precompile each oneOf's paths
      mapping["_oneOfs"].each do |one_of_mapping|
        parse_path(one_of_mapping["_discriminator"]) if one_of_mapping["_discriminator"]
        parse_path(one_of_mapping["_variant_path"]) if one_of_mapping["_variant_path"]

        one_of_mapping.each do |key, variant_mapping|
          next if key.start_with?("_")
          next unless variant_mapping.is_a?(Hash)

          variant_mapping.each do |source_path, target_path|
            parse_path(source_path.to_s)
            parse_path(target_path.to_s)
          end
        end
      end
    end

    # Precompiles JSONSchemer instances for variant schemas
    # This is called during initialization to prepare the schemer cache
    #
    # @return [void]
    def precompile_schemers
      return unless variant_schemas

      variant_schemas.each do |name, schema|
        schemer_cache[name] = JSONSchemer.schema(schema)
      end
    end

    # Returns the effective discriminator path
    #
    # @return [String, nil] The discriminator path from constructor or mapping
    def effective_discriminator
      discriminator || mapping["_discriminator"]
    end

    # Precompiles paths for discriminator-based variant mappings
    #
    # @return [void]
    def precompile_variant_mappings
      mapping.each do |key, variant_mapping|
        next if key.start_with?("_") # Skip metadata keys like _discriminator, _variant_schemas, _variant_path
        next unless variant_mapping.is_a?(Hash)

        variant_mapping.each do |source_path, target_path|
          parse_path(source_path.to_s)
          parse_path(target_path.to_s)
        end
      end
    end

    # Precompiles paths for flat (non-discriminator) mappings
    #
    # @return [void]
    def precompile_flat_mapping
      mapping.each do |source_path, target_path|
        parse_path(source_path.to_s)
        parse_path(target_path.to_s)
      end
    end

    # Parses a slash-notation path into structured path parts
    # Uses memoization for performance optimization
    #
    # @param path [String] The slash-notation path (e.g., "user/address/street")
    # @return [Array<Hash>] Array of frozen path parts with :key and :array attributes
    def parse_path(path)
      path_cache[path] ||= path.split("/").map do |part|
        if part.end_with?("[]")
          {key: part[0...-2], array: true}.freeze
        else
          {key: part, array: false}.freeze
        end
      end.freeze
    end

    # Extracts a value from nested data structure using the parsed path parts
    #
    # @param data [Hash, Array, Object] The data to extract value from
    # @param path_parts [Array<Hash>] The parsed path parts
    # @param index [Integer] Current position in path_parts (avoids array slicing)
    # @return [Object, nil] The extracted value or nil if not found
    def extract_value(data, path_parts, index = 0)
      return data if index >= path_parts.length

      current_part = path_parts[index]
      key = current_part[:key]

      case data
      when Hash
        return nil unless data.key?(key.to_s)
        value = data[key.to_s]
        if current_part[:array] && value.is_a?(Array)
          # Process each object in the array separately
          value.map { |item| extract_value(item, path_parts, index + 1) }
        else
          extract_value(value, path_parts, index + 1)
        end
      when Array
        if current_part[:array]
          # Map through array elements with remaining path
          data.map { |item| extract_value(item, path_parts, index + 1) }
        else
          # Try to extract from each array element with the full path
          data.map { |item| extract_value(item, path_parts, index) }
        end
      else
        (index >= path_parts.length - 1) ? data : nil
      end
    end

    # Sets a value in a result hash at the specified path
    #
    # @param result [Hash] The result hash to modify
    # @param path_parts [Array<Hash>] The parsed path parts
    # @param value [Object] The value to set
    # @param index [Integer] Current position in path_parts (avoids array slicing)
    # @return [Hash] The modified result hash with string keys
    def set_value(result, path_parts, value, index = 0)
      return result if index >= path_parts.length

      current_part = path_parts[index]
      key = current_part[:key].to_s
      last_part = index == path_parts.length - 1

      if value.nil?
        # Skip setting nil values
        return result
      end

      if last_part
        result[key] = value
      elsif current_part[:array] && value.is_a?(Array)
        result[key] ||= []
        value.each_with_index do |v, i|
          next if v.nil? # Skip nil items in array
          result[key][i] ||= {}
          set_value(result[key][i], path_parts, v, index + 1)
          # Remove keys with nil values from each object
          result[key][i].delete_if { |_, val| val.nil? }
        end
        # Remove nils and compact the array
        result[key] = result[key].compact
      else
        result[key] ||= {}
        set_value(result[key], path_parts, value, index + 1)
        # Remove keys with nil values from nested object
        result[key].delete_if { |_, val| val.nil? }
      end
      result
    end
  end
end

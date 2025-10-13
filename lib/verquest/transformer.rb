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
  class Transformer
    # Creates a new Transformer with the specified mapping
    #
    # @param mapping [Hash] A hash where keys are source paths and values are target paths
    # @return [Transformer] A new transformer instance
    def initialize(mapping:)
      @mapping = mapping
      @path_cache = {} # Cache for parsed paths to improve performance
      precompile_paths # Prepare cache during initialization
    end

    # Transforms input parameters according to the provided mapping
    #
    # @param params [Hash] The input parameters to transform
    # @return [Hash] The transformed parameters with symbol keys
    def call(params)
      result = {}

      mapping.each do |source_path, target_path|
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
    attr_reader :mapping, :path_cache

    # Precompiles all paths from the mapping to improve performance
    # This is called during initialization to prepare the cache
    #
    # @return [void]
    def precompile_paths
      mapping.each do |source_path, target_path|
        parse_path(source_path.to_s)
        parse_path(target_path.to_s)
      end
    end

    # Parses a slash-notation path into structured path parts
    # Uses memoization for performance optimization
    #
    # @param path [String] The slash-notation path (e.g., "user/address/street")
    # @return [Array<Hash>] Array of path parts with :key and :array attributes
    def parse_path(path)
      path_cache[path] ||= path.split("/").map do |part|
        if part.end_with?("[]")
          {key: part[0...-2], array: true}
        else
          {key: part, array: false}
        end
      end
    end

    # Extracts a value from nested data structure using the parsed path parts
    #
    # @param data [Hash, Array, Object] The data to extract value from
    # @param path_parts [Array<Hash>] The parsed path parts
    # @return [Object, nil] The extracted value or nil if not found
    def extract_value(data, path_parts)
      return data if path_parts.empty?

      current_part = path_parts.first
      remaining_path = path_parts[1..]
      key = current_part[:key]

      case data
      when Hash
        return nil unless data.key?(key.to_s)
        value = data[key.to_s]
        if current_part[:array] && value.is_a?(Array)
          # Process each object in the array separately
          value.map { |item| extract_value(item, remaining_path) }
        else
          extract_value(value, remaining_path)
        end
      when Array
        if current_part[:array]
          # Map through array elements with remaining path
          data.map { |item| extract_value(item, remaining_path) }
        else
          # Try to extract from each array element with the full path
          data.map { |item| extract_value(item, path_parts) }
        end
      else
        remaining_path.empty? ? data : nil
      end
    end

    # Sets a value in a result hash at the specified path
    #
    # @param result [Hash] The result hash to modify
    # @param path_parts [Array<Hash>] The parsed path parts
    # @param value [Object] The value to set
    # @return [Hash] The modified result hash with symbol keys
    def set_value(result, path_parts, value)
      return result if path_parts.empty?

      current_part = path_parts.first
      remaining_path = path_parts[1..]
      key = current_part[:key].to_s

      if value.nil?
        # Skip setting nil values
        return result
      end

      if remaining_path.empty?
        result[key] = value
      elsif current_part[:array] && value.is_a?(Array)
        result[key] ||= []
        value.each_with_index do |v, i|
          next if v.nil? # Skip nil items in array
          result[key][i] ||= {}
          set_value(result[key][i], remaining_path, v)
          # Remove keys with nil values from each object
          result[key][i].delete_if { |_, val| val.nil? }
        end
        # Remove nils and compact the array
        result[key] = result[key].compact
      else
        result[key] ||= {}
        set_value(result[key], remaining_path, value)
        # Remove keys with nil values from nested object
        result[key].delete_if { |_, val| val.nil? }
      end
      result
    end
  end
end

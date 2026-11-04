# frozen_string_literal: true

module Verquest
  class Transformer
    # A parsed slash-separated path, like "user/addresses[]/zip"
    #
    # A part ending with "[]" is an array: reading it reads every item, and
    # writing it writes every item at its position. Paths are parsed once,
    # when the transformer is built, and reading or writing allocates only
    # the values and hashes it returns.
    #
    # @example
    #   path = Path.new("users[]/name")
    #   path.extract({"users" => [{"name" => "A"}, {}]}) # => ["A", Path::NOT_FOUND]
    #   path.set({}, ["A", Path::NOT_FOUND]) # => {"users" => [{"name" => "A"}, {}]}
    #
    # Internal to the transformer, not part of the public API.
    class Path
      # Returned when a key is not in the data, to tell it apart from a null value
      NOT_FOUND = Object.new.freeze

      # A value below an explicit null in the data
      #
      # Returned by #extract with `nulls: true` when a parent of the path is
      # null, so the matching part of the target path can be set to null too.
      #
      # @!attribute [r] depth_below
      #   @return [Integer] How many path parts are below the null parent
      NullParent = Data.define(:depth_below)

      # One part of a path
      #
      # @!attribute [r] key
      #   @return [String] The hash key
      # @!attribute [r] array
      #   @return [Boolean] Whether the key holds an array
      Part = Data.define(:key, :array)

      # @!attribute [r] to_s
      #   @return [String] The path as given
      # @!attribute [r] parts
      #   @return [Array<Part>] The parsed parts
      attr_reader :to_s, :parts

      # @param path [String] The slash-separated path
      def initialize(path)
        @to_s = path.dup.freeze
        @parts = path.split("/").map { |part| Part.new(key: part.delete_suffix("[]"), array: part.end_with?("[]")) }.freeze
        # One NullParent per part, so reading a null allocates nothing
        @null_parents = Array.new(parts.length) { |index| NullParent.new(depth_below: parts.length - index - 1) }.freeze
        @last = parts.length - 1
        freeze
      end

      # @return [Boolean] True for the empty path, which reads the data itself
      def empty?
        parts.empty?
      end

      # Reads the value at this path
      #
      # @param data [Object] The data to read from
      # @param nulls [Boolean] Whether to return a NullParent for a value below an explicit null
      # @return [Object, NullParent, NOT_FOUND] The value, an array of values for array parts, or NOT_FOUND
      def extract(data, nulls: false)
        extract_at(data, 0, nulls)
      end

      # Writes a value at this path
      #
      # Every item of an array keeps its position, even when none of its
      # values are present, so empty items stay empty hashes. A NullParent
      # sets the matching part of this path to null, unless it already has a value.
      #
      # @param result [Hash] The hash to write to
      # @param value [Object, NullParent] The value, or an array of values for array parts
      # @return [Hash] The result
      def set(result, value)
        set_at(result, value, 0)
      end

      private

      # @!attribute [r] null_parents
      #   @return [Array<NullParent>] The NullParent for a null at each part
      # @!attribute [r] last
      #   @return [Integer] The index of the last part
      attr_reader :null_parents, :last

      # @param data [Object] The data to read from
      # @param index [Integer] The current part
      # @param nulls [Boolean] Whether to return a NullParent below an explicit null
      # @return [Object, NullParent, NOT_FOUND] The value
      def extract_at(data, index, nulls)
        return data if index > last

        case data
        when Hash then extract_from_hash(data, index, nulls)
        # An array reached by a part without "[]" is read item by item
        when Array then data.map { |item| extract_at(item, index, nulls) }
        else NOT_FOUND
        end
      end

      # @param data [Hash] The hash to read from
      # @param index [Integer] The current part
      # @param nulls [Boolean] Whether to return a NullParent below an explicit null
      # @return [Object, NullParent, NOT_FOUND] The value
      def extract_from_hash(data, index, nulls)
        part = parts[index]
        value = data.fetch(part.key) { return NOT_FOUND }
        return null_parents[index] if value.nil? && nulls && index < last
        return value.map { |item| extract_at(item, index + 1, nulls) } if part.array && value.is_a?(Array)

        extract_at(value, index + 1, nulls)
      end

      # @param result [Hash] The hash to write to
      # @param value [Object, NullParent] The value
      # @param index [Integer] The current part
      # @return [Hash] The result
      def set_at(result, value, index)
        return set_null(result, index, [last - value.depth_below, index].max) if value.is_a?(NullParent)

        part = parts[index]
        if index == last
          result[part.key] = value.is_a?(Array) ? plain(value) : value
        elsif part.array && value.is_a?(Array)
          set_items(result[part.key] ||= [], value, index + 1)
        else
          set_at(result[part.key] ||= {}, value, index + 1)
        end
        result
      end

      # @param items [Array<Hash>] The array to write to
      # @param values [Array<Object>] The values, one per item
      # @param index [Integer] The part below the array
      # @return [void]
      def set_items(items, values, index)
        values.each_with_index do |value, position|
          item = (items[position] ||= {})
          set_at(item, value, index) unless value.equal?(NOT_FOUND)
        end
      end

      # Turns the markers in an array of values into nulls
      #
      # An array of values reaches the last part when a property is moved out
      # of collection items with map: "/...". Items without the value keep
      # their position as null.
      #
      # @param values [Array<Object>] The values, possibly nested
      # @return [Array<Object>] The values with NOT_FOUND and NullParent as nil
      def plain(values)
        # Most arrays are array fields without markers, which are kept as they are
        return values unless values.any? { |value| value.is_a?(Array) || value.is_a?(NullParent) || value.equal?(NOT_FOUND) }

        values.map do |value|
          case value
          when Array then plain(value)
          when NullParent, NOT_FOUND then nil
          else value
          end
        end
      end

      # Sets the part at null_index to null, unless it already has a value
      #
      # The null goes as many parts above the end of this path as it is above
      # the end of the source path, but never above the current part.
      #
      # @param result [Hash] The hash to write to
      # @param index [Integer] The current part
      # @param null_index [Integer] The part to set to null
      # @return [Hash] The result
      def set_null(result, index, null_index)
        node = result
        index.upto(null_index - 1) do |position|
          node = (node[parts[position].key] ||= {})
          return result unless node.is_a?(Hash)
        end
        node[parts[null_index].key] = nil unless node.key?(parts[null_index].key)
        result
      end
    end
  end
end

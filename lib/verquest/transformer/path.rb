# frozen_string_literal: true

module Verquest
  class Transformer
    # A parsed slash-separated path, like "user/addresses[]/zip"
    #
    # A part ending with "[]" is an array: reading it reads every item, and
    # writing it writes every item at its position.
    #
    # @example
    #   path = Path.new("users[]/name")
    #   path.extract({"users" => [{"name" => "A"}, {}]}) # => ["A", Path::NOT_FOUND]
    #   path.set({}, ["A", Path::NOT_FOUND]) # => {"users" => [{"name" => "A"}, {}]}
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
      NullParent = Struct.new(:depth_below)

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
        @to_s = path.freeze
        @parts = path.split("/").map { |part| Part.new(key: part.delete_suffix("[]"), array: part.end_with?("[]")) }.freeze
        freeze
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

      # @param data [Object] The data to read from
      # @param index [Integer] The current part
      # @param nulls [Boolean] Whether to return a NullParent below an explicit null
      # @return [Object, NullParent, NOT_FOUND] The value
      def extract_at(data, index, nulls)
        return data if index >= parts.length

        part = parts[index]
        case data
        when Hash
          extract_from_hash(data, part, index, nulls)
        when Array
          # An array reached by a part without "[]" is read item by item
          data.map { |item| extract_at(item, index, nulls) }
        else
          NOT_FOUND
        end
      end

      # @param data [Hash] The hash to read from
      # @param part [Part] The current part
      # @param index [Integer] The current part index
      # @param nulls [Boolean] Whether to return a NullParent below an explicit null
      # @return [Object, NullParent, NOT_FOUND] The value
      def extract_from_hash(data, part, index, nulls)
        return NOT_FOUND unless data.key?(part.key)

        value = data[part.key]
        return NullParent.new(parts.length - index - 1) if nulls && value.nil? && index < parts.length - 1
        return value.map { |item| extract_at(item, index + 1, nulls) } if part.array && value.is_a?(Array)

        extract_at(value, index + 1, nulls)
      end

      # @param result [Hash] The hash to write to
      # @param value [Object, NullParent] The value
      # @param index [Integer] The current part
      # @return [Hash] The result
      def set_at(result, value, index)
        return set_null_parent(result, value, index) if value.is_a?(NullParent)

        part = parts[index]
        if index == parts.length - 1
          result[part.key] = value
        elsif part.array && value.is_a?(Array)
          items = (result[part.key] ||= [])
          value.each_with_index do |item_value, item_index|
            items[item_index] ||= {}
            set_at(items[item_index], item_value, index + 1) unless item_value.equal?(NOT_FOUND)
          end
        else
          set_at(result[part.key] ||= {}, value, index + 1)
        end
        result
      end

      # Sets the target of a value below an explicit null to null
      #
      # The null goes as many parts above the end of this path as it is above
      # the end of the source path, but never above the current part.
      #
      # @param result [Hash] The hash to write to
      # @param null_parent [NullParent] The null found in the source
      # @param index [Integer] The current part
      # @return [Hash] The result
      def set_null_parent(result, null_parent, index)
        null_path = Path.new(parts.drop(index).first([parts.length - index - null_parent.depth_below, 1].max).map(&:key).join("/"))
        null_path.set(result, nil) if null_path.extract(result).equal?(NOT_FOUND)
        result
      end
    end
  end
end

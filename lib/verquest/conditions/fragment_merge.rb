# frozen_string_literal: true

module Verquest
  module Conditions
    # Deep-merges the schema fragments of several rules into one fragment
    #
    # `required` lists are concatenated without duplicates and nested hashes
    # (like `properties`) are merged. Two different values for the same keyword
    # raise, so `equals :kind, "a"` and `equals :kind, "b"` in one block fail
    # instead of silently keeping one of them.
    #
    # @example
    #   FragmentMerge.call([{"required" => ["a"]}, {"required" => ["a", "b"]}])
    #   # => {"required" => ["a", "b"]}
    module FragmentMerge
      module_function

      # Merges the fragments in order
      #
      # @param fragments [Array<Hash>] The schema fragments to merge
      # @return [Hash] The merged fragment
      # @raise [ArgumentError] If two fragments set the same keyword to different values
      def call(fragments)
        fragments.reduce({}) { |merged, fragment| merge(merged, fragment) }
      end

      # Merges two fragments
      #
      # @param left [Hash] The fragment merged so far
      # @param right [Hash] The fragment to merge into it
      # @return [Hash] The merged fragment
      def merge(left, right)
        left.merge(right) { |key, left_value, right_value| merge_value(key, left_value, right_value) }
      end

      # Merges two values of the same keyword
      #
      # @param key [String] The keyword
      # @param left_value [Object] The value merged so far
      # @param right_value [Object] The value to merge into it
      # @return [Object] The merged value
      # @raise [ArgumentError] If the values differ and can't be combined
      def merge_value(key, left_value, right_value)
        return left_value | right_value if key == "required" && left_value.is_a?(::Array)
        return merge(left_value, right_value) if left_value.is_a?(Hash) && right_value.is_a?(Hash)
        return left_value if left_value == right_value

        raise ArgumentError, "Conflicting rules for '#{key}': #{left_value.inspect} and #{right_value.inspect}"
      end
    end
  end
end

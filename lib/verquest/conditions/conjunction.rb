# frozen_string_literal: true

module Verquest
  module Conditions
    # Combines schema fragments that must all hold
    #
    # Unlike FragmentMerge, a clash is not an error here: the fragments are
    # requirements on the same payload, so a fragment that can't be merged
    # (for example `note: false` against `note: {type: string}`) is added to
    # `allOf` instead. Used for the documented oneOf variants, which join the
    # scope schema, the branch rules and the `given` rules.
    #
    # @example
    #   Conjunction.call([{"properties" => {"note" => {"type" => "string"}}}, {"properties" => {"note" => false}}])
    #   # => {"properties" => {"note" => {"type" => "string"}}, "allOf" => [{"properties" => {"note" => false}}]}
    module Conjunction
      module_function

      # Combines the fragments in order
      #
      # @param fragments [Array<Hash>] The schema fragments that must all hold
      # @return [Hash] The combined fragment
      def call(fragments)
        fragments.reduce({}) { |combined, fragment| conjoin(combined, fragment) }
      end

      # Merges two fragments, or adds the second to `allOf` when they clash
      #
      # @param left [Hash] The fragment combined so far
      # @param right [Hash] The fragment to add
      # @return [Hash] The combined fragment
      def conjoin(left, right)
        FragmentMerge.merge(left, right)
      rescue ArgumentError
        left.merge("allOf" => left.fetch("allOf", []) + [right])
      end
    end
  end
end

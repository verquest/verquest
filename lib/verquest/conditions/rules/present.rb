# frozen_string_literal: true

module Verquest
  module Conditions
    module Rules
      # Requires the named properties to be present
      #
      # @example
      #   Present.new(%i[a b]).to_schema(in_given: false)
      #   # => {"required" => ["a", "b"]}
      class Present < NamesRule
        # Builds the schema fragment for this rule
        #
        # @param in_given [Boolean] Whether the rule is used inside `given` (no effect for this rule)
        # @return [Hash] The schema fragment
        def to_schema(in_given: false)
          {"required" => property_names}
        end

        # Checks whether every payload of the variant matches this rule
        #
        # @param variant [Hash] The documented oneOf variant
        # @return [Boolean] true when the variant requires every named property
        def holds_in?(variant)
          property_names.all? { |property_name| VariantShape.required?(variant, property_name) }
        end

        # Checks whether no payload of the variant matches this rule
        #
        # @param variant [Hash] The documented oneOf variant
        # @return [Boolean] true when the variant forbids a named property
        def fails_in?(variant)
          property_names.any? { |property_name| VariantShape.forbidden?(variant, property_name) }
        end
      end
    end
  end
end

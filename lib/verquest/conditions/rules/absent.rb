# frozen_string_literal: true

module Verquest
  module Conditions
    module Rules
      # Forbids the named properties
      #
      # A forbidden property gets the `false` schema, so a payload that sends it
      # is reported with a single error at the property's pointer.
      #
      # @example
      #   Absent.new(%i[a b]).to_schema(in_given: false)
      #   # => {"properties" => {"a" => false, "b" => false}}
      class Absent < NamesRule
        # Builds the schema fragment for this rule
        #
        # @param in_given [Boolean] Whether the rule is used inside `given` (no effect for this rule)
        # @return [Hash] The schema fragment
        def to_schema(in_given: false)
          {"properties" => property_names.to_h { |name| [name, false] }}
        end

        # Checks whether every payload of the variant matches this rule
        #
        # @param variant [Hash] The documented oneOf variant
        # @return [Boolean] true when the variant forbids every named property
        def holds_in?(variant)
          property_names.all? { |property_name| VariantShape.forbidden?(variant, property_name) }
        end

        # Checks whether no payload of the variant matches this rule
        #
        # @param variant [Hash] The documented oneOf variant
        # @return [Boolean] true when the variant requires a named property
        def fails_in?(variant)
          property_names.any? { |property_name| VariantShape.required?(variant, property_name) }
        end
      end
    end
  end
end

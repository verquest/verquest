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
      end
    end
  end
end

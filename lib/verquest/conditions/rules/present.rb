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
      end
    end
  end
end

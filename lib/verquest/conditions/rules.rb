# frozen_string_literal: true

module Verquest
  module Conditions
    # Rules used inside `given`, `then_apply`, `else_apply` and `depends_on`
    #
    # Each rule names properties of the scope its condition belongs to and
    # builds a JSON Schema fragment. Every rule responds to `#property_names`
    # (used to catch unknown names) and `#to_schema(in_given:)`.
    #
    # @see Verquest::Conditions::RuleSet Combines the rules of one block
    module Rules
      # This module is a namespace for the rule classes
      # Each rule is defined in its own file under lib/verquest/conditions/rules/
    end
  end
end

# frozen_string_literal: true

module Verquest
  # Conditional schemas (`if` / `then` / `else`)
  #
  # A condition tests which keys a payload has and what values they hold, and
  # applies one of two branches. Branches can declare properties and rules.
  # Branch properties are listed at the scope level, next to the regular
  # properties, and the branches only get rules (`required`, `name: false`, ...).
  #
  # @example Price adjustment with two variants
  #   class PriceAdjustmentRequest < Verquest::Base
  #     version "2025-09" do
  #       field :effective_from, type: :string, required: true
  #
  #       condition :pricing do
  #         given { present :percentages }
  #         then_apply do
  #           object :percentages, required: true do
  #             field :unit_types, type: :number
  #           end
  #         end
  #         else_apply do
  #           field :percentage, type: :number, required: true
  #         end
  #       end
  #     end
  #   end
  #
  # @see Verquest::Conditions::Condition
  # @see Verquest::HelperMethods::ConditionalProperties
  module Conditions
    # This module is a namespace for the condition classes
    # Each class is defined in its own file under lib/verquest/conditions/
  end
end

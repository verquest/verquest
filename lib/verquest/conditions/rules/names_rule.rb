# frozen_string_literal: true

module Verquest
  module Conditions
    module Rules
      # Base class for rules that name one or more properties
      #
      # @abstract Subclass and implement `#to_schema(in_given:)`
      class NamesRule
        # @!attribute [r] property_names
        #   @return [Array<String>] The names of the properties the rule uses
        attr_reader :property_names

        # Initialize a new rule
        #
        # @param names [Array<Symbol, String>] The properties the rule names
        def initialize(names)
          @property_names = names.map(&:to_s)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Verquest
  module Conditions
    # The `then` or `else` part of a condition
    #
    # A branch is a DSL scope: `field`, `object` and the rest add properties
    # through {#add}, and rule methods add rules through {#add_rule}. The
    # properties are listed at the scope level by
    # {Verquest::HelperMethods::ConditionalProperties}, so the branch schema
    # only holds rules: the required names, the rule fragments and `false`
    # for the names the other branch declares.
    class Branch
      include HelperMethods::RequiredProperties

      # @!attribute [r] properties
      #   @return [Hash<String, Verquest::Properties::Base>] The properties declared in the branch
      #
      # @!attribute [r] documentation
      #   @return [Hash<String, Object>] The title, description and deprecated flag of the branch's oneOf variant
      attr_reader :properties, :documentation

      # Initialize an empty branch
      #
      # The documentation is used only when the condition is documented as a oneOf.
      #
      # @param title [String, nil] Title of the branch's oneOf variant
      # @param description [String, nil] Description of the branch's oneOf variant
      # @param deprecated [Boolean, nil] Whether the branch's oneOf variant is deprecated
      def initialize(title: nil, description: nil, deprecated: nil)
        @properties = {}
        @rules = RuleSet.new
        @documentation = {"title" => title, "description" => description, "deprecated" => deprecated}.compact
      end

      # Add a property declared in the branch
      #
      # @param property [Verquest::Properties::Base] The property to add
      # @return [Verquest::Properties::Base] The added property
      # @raise [ArgumentError] If the property is a oneOf
      def add(property)
        raise ArgumentError, "one_of can not be declared inside a condition" if property.is_a?(Properties::OneOf)

        properties[property.name] = property
      end

      # Add a rule
      #
      # @param rule [#to_schema, #property_names] The rule to add
      # @return [Array] The rules
      def add_rule(rule)
        rules.add_rule(rule)
      end

      # Returns the names of the properties the rules use
      #
      # @return [Array<String>] The property names, without duplicates
      def rule_property_names
        rules.property_names
      end

      # Builds the branch schema fragment
      #
      # @param forbidden [Array<String>] Property names the branch forbids (declared by the other branch only)
      # @return [Hash] The schema fragment
      # @raise [ArgumentError] If two rules conflict or the branch requires a forbidden name
      def to_schema(forbidden: [])
        FragmentMerge.call([required_schema, rules.to_schema, forbidden_schema(forbidden)]).tap do |schema|
          check_satisfiable!(schema, forbidden)
        end
      end

      private

      # @!attribute [r] rules
      #   @return [Verquest::Conditions::RuleSet] The rules of the branch
      attr_reader :rules

      # Builds the fragment for the branch properties' requiredness
      #
      # @return [Hash] The `required` and `dependentRequired` fragment
      def required_schema
        {}.tap do |schema|
          schema["required"] = required_properties if required_properties.any?
          schema["dependentRequired"] = dependent_required_properties if dependent_required_properties.any?
        end
      end

      # Checks that the branch doesn't require a name it forbids
      #
      # @param schema [Hash] The branch schema fragment
      # @param forbidden [Array<String>] The forbidden property names
      # @return [void]
      # @raise [ArgumentError] If a required name is forbidden, which no payload could satisfy
      def check_satisfiable!(schema, forbidden)
        conflict = schema.fetch("required", []) & forbidden
        raise ArgumentError, "Branch requires #{conflict.join(", ")}, which only the other branch declares" if conflict.any?
      end

      # Builds the fragment that forbids properties
      #
      # @param names [Array<String>] The forbidden property names
      # @return [Hash] The `properties` fragment with a `false` schema per name
      def forbidden_schema(names)
        return {} if names.empty?

        {"properties" => names.to_h { |name| [name, false] }}
      end
    end
  end
end

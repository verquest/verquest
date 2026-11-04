# frozen_string_literal: true

module Verquest
  module HelperMethods
    # Module that adds conditions (`if` / `then` / `else`) to a scope
    #
    # Included in Version, Properties::Object and Properties::Collection (inline
    # items). The including class must set `@conditions = []` and have a
    # `properties` hash.
    #
    # The branch properties of all conditions are listed next to the regular
    # properties ({#all_properties}), so `additionalProperties` keeps working and
    # the mapping is the flat union of both. The scope schema gets the
    # condition's `if` / `then` / `else` keywords, or one `allOf` entry per
    # condition when there are several.
    module ConditionalProperties
      # Schema options that can't be combined with conditions
      RESERVED_KEYWORDS = %w[if then else allOf].freeze

      # JSON Schema versions that ignore `if` / `then` / `else` and would accept every payload
      UNSUPPORTED_DIALECTS = %i[draft4 draft6 openapi30].freeze

      # @!attribute [r] conditions
      #   @return [Array<Verquest::Conditions::Condition>] The conditions in declaration order
      attr_reader :conditions

      # Add a condition to this scope
      #
      # A named condition can be declared only once per scope. To replace an
      # inherited one, call `exclude_conditions` first.
      #
      # @param condition [Verquest::Conditions::Condition] The condition to add
      # @return [Array<Verquest::Conditions::Condition>] The conditions
      # @raise [ArgumentError] If a condition with the same name is already defined
      def add_condition(condition)
        raise ArgumentError, "Condition '#{condition.name}' is already defined" if condition.name && conditions.any? { |other| other.name == condition.name }

        conditions << condition
      end

      # Remove a named condition from this scope
      #
      # @param name [Symbol, String] The condition name
      # @return [Verquest::Conditions::Condition] The removed condition
      # @raise [ArgumentError] If no condition has that name
      def remove_condition(name)
        condition = conditions.find { |candidate| candidate.name == name.to_s }
        raise ArgumentError, "Condition '#{name}' is not defined" unless condition

        conditions.delete(condition)
      end

      # Returns the regular properties followed by the branch properties
      #
      # Computed on every call, so it always reflects the current declarations.
      #
      # @return [Hash<String, Verquest::Properties::Base>] All properties listed in the scope schema
      # @raise [ArgumentError] If a branch property clashes with another declaration
      def all_properties
        properties.merge(conditional_properties)
      end

      private

      # Merges the branch properties of all conditions
      #
      # @return [Hash<String, Verquest::Properties::Base>] The branch properties
      # @raise [ArgumentError] If a branch property clashes with another declaration
      def conditional_properties
        Conditions::PropertyMerge.call(conditions.map(&:properties)).tap { |branch_properties| check_property_clashes!(branch_properties) }
      end

      # Checks that no branch property is also declared on the scope
      #
      # @param branch_properties [Hash<String, Verquest::Properties::Base>] The branch properties
      # @return [void]
      # @raise [ArgumentError] If a branch property is also declared on the scope
      def check_property_clashes!(branch_properties)
        clash = branch_properties.keys.find { |name| properties.key?(name) }
        raise ArgumentError, "Property '#{clash}' is declared both outside and inside a condition" if clash
      end

      # Adds the conditional keywords to a scope schema
      #
      # In documentation, a condition declared with `document_as: :one_of`
      # replaces the schema with a oneOf of its branches instead.
      #
      # @param schema [Hash] The scope schema, changed in place
      # @param documentation [Boolean] Whether the schema is the documented one (`to_schema`)
      # @return [Hash] The schema
      # @raise [ArgumentError] If a condition is invalid or the schema already has conditional keywords
      def add_conditions(schema, documentation: false)
        return schema if conditions.empty?

        validate_conditions(schema)
        return schema.replace(conditions.first.to_one_of_schema(schema)) if documentation && conditions.first.document_as

        schema.merge!(conditions_schema)
      end

      # Checks the conditions before they are added to the schema
      #
      # @param schema [Hash] The scope schema
      # @return [void]
      # @raise [ArgumentError] If the JSON Schema version ignores conditions, the schema already
      #   has conditional keywords, a condition documented as one_of is not alone, or a condition is invalid
      def validate_conditions(schema)
        dialect = Verquest.configuration.json_schema_version
        raise ArgumentError, "Conditions need json_schema_version draft7 or later, or openapi31 (got #{dialect})" if UNSUPPORTED_DIALECTS.include?(dialect)
        raise ArgumentError, "Raw if, then, else or allOf schema options can not be combined with conditions" if schema.keys.intersect?(RESERVED_KEYWORDS)
        raise ArgumentError, "A condition documented as one_of must be the only condition in its version" if conditions.size > 1 && conditions.any?(&:document_as)

        conditions.each { |condition| condition.validate!(all_properties.keys) }
      end

      # Builds the conditional keywords
      #
      # @return [Hash] `if` / `then` / `else` for one condition, `allOf` for several
      def conditions_schema
        return conditions.first.to_schema if conditions.one?

        {"allOf" => conditions.map(&:to_schema)}
      end
    end
  end
end

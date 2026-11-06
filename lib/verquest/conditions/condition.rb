# frozen_string_literal: true

module Verquest
  module Conditions
    # One `if` / `then` / `else`
    #
    # Holds the `given` rule set (the `if`) and up to two branches. A property
    # declared in one branch only is forbidden in the other, so when only one
    # branch declares properties, the other one is generated.
    #
    # @example
    #   condition = Condition.new(name: :pricing)
    #   condition.open(:given).add_rule(Rules::Present.new(%i[percentages]))
    #   condition.open(:then).add(Properties::Field.new(name: :percentages, type: :number, required: true))
    #   condition.to_schema
    #   # => {
    #   #   "if" => {"required" => ["percentages"]},
    #   #   "then" => {"required" => ["percentages"]},
    #   #   "else" => {"properties" => {"percentages" => false}}
    #   # }
    class Condition
      # The scope class for each part of a condition
      PARTS = {given: RuleSet, then: Branch, else: Branch}.freeze

      # The ways a condition can be rendered in `to_schema` instead of `if` / `then` / `else`
      DOCUMENT_AS = %i[one_of].freeze

      # @!attribute [r] name
      #   @return [String, nil] The condition name, used to exclude it in a later version
      #
      # @!attribute [r] document_as
      #   @return [Symbol, nil] `:one_of` when `to_schema` renders the condition as a oneOf
      attr_reader :name, :document_as

      # Initialize a new Condition
      #
      # @param name [Symbol, String, nil] Optional name
      # @param document_as [Symbol, nil] `:one_of` to render the condition as a oneOf in `to_schema`
      # @raise [ArgumentError] If document_as is not supported
      def initialize(name: nil, document_as: nil)
        raise ArgumentError, "document_as must be :one_of (got #{document_as.inspect})" unless document_as.nil? || DOCUMENT_AS.include?(document_as)

        @name = name&.to_s
        @document_as = document_as
        @parts = {}
      end

      # Starts one part of the condition
      #
      # @param part [Symbol] :given, :then or :else
      # @param options [Hash] Branch documentation (title, description, deprecated), for :then and :else only
      # @return [Verquest::Conditions::RuleSet, Verquest::Conditions::Branch] The new part, used as the DSL scope
      # @raise [ArgumentError] If the part was already declared
      def open(part, **options)
        raise ArgumentError, "#{part} can be declared only once in #{label}" if parts.key?(part)

        parts[part] = PARTS.fetch(part).new(**options)
      end

      # Rejects properties declared outside a branch
      #
      # @param _property [Verquest::Properties::Base] The property that was declared
      # @raise [ArgumentError] Always
      def add(_property)
        raise ArgumentError, "Properties of #{label} must be declared inside then_apply or else_apply"
      end

      # Checks the shape of the condition and the names its rules use
      #
      # @param property_names [Array<String>] The names declared in the scope and in its branches
      # @return [nil]
      # @raise [ArgumentError] If `given` has no rules, neither branch is declared, or a rule uses an unknown name
      def validate!(property_names)
        raise ArgumentError, "#{label} needs a given block with at least one rule" if given.rules.empty?
        raise ArgumentError, "#{label} needs a then_apply or else_apply block" unless parts.key?(:then) || parts.key?(:else)

        unknown = rule_property_names - property_names
        raise ArgumentError, "#{label} uses unknown properties: #{unknown.join(", ")}" if unknown.any?
      end

      # Returns the branch properties to list at the scope level
      #
      # @return [Hash<String, Verquest::Properties::Base>] The properties of both branches
      # @raise [ArgumentError] If the branches declare the same name differently
      def properties
        PropertyMerge.call([branch(:then).properties, branch(:else).properties])
      end

      # Returns the names of the properties the rules use
      #
      # @return [Array<String>] The property names, without duplicates
      def rule_property_names
        (given.property_names + branch(:then).rule_property_names + branch(:else).rule_property_names).uniq
      end

      # Builds the `if` / `then` / `else` keywords
      #
      # @return [Hash] The keywords, without empty branches
      def to_schema
        {
          "if" => given.to_schema(in_given: true),
          "then" => branch_schema(:then, other: :else),
          "else" => branch_schema(:else, other: :then)
        }.reject { |_, fragment| fragment.empty? }
      end

      # Builds a oneOf with one variant per branch, for documentation
      #
      # Each variant holds the scope's properties without the ones only the
      # other branch declares, plus its branch's rules. The `then` variant also
      # holds the `given` rules, unless its required and forbidden properties
      # already satisfy them, and the `else` variant their negation, unless
      # they already rule `given` out. So exactly one variant matches every
      # payload the `if` / `then` / `else` schema accepts.
      #
      # @param scope_schema [Hash] The scope schema with every property listed
      # @return [Hash] The scope description and the `oneOf` variants
      def to_one_of_schema(scope_schema)
        {"description" => scope_schema["description"], "oneOf" => [variant_schema(scope_schema, :then, other: :else), variant_schema(scope_schema, :else, other: :then)]}.compact
      end

      private

      # @!attribute [r] parts
      #   @return [Hash<Symbol, Object>] The declared parts, keyed by :given, :then and :else
      attr_reader :parts

      # @return [Verquest::Conditions::RuleSet] The `given` rules, empty if not declared
      def given
        parts.fetch(:given) { RuleSet.new }
      end

      # @param part [Symbol] :then or :else
      # @return [Verquest::Conditions::Branch] The branch, empty if not declared
      def branch(part)
        parts.fetch(part) { Branch.new }
      end

      # Builds one branch, forbidding the names only the other branch declares
      #
      # @param part [Symbol] :then or :else
      # @param other [Symbol] The other branch
      # @return [Hash] The branch schema fragment
      def branch_schema(part, other:)
        branch(part).to_schema(forbidden: branch(other).properties.keys - branch(part).properties.keys)
      end

      # Builds the oneOf variant for one branch
      #
      # @param scope_schema [Hash] The scope schema with every property listed
      # @param part [Symbol] :then or :else
      # @param other [Symbol] The other branch
      # @return [Hash] The variant schema
      def variant_schema(scope_schema, part, other:)
        excluded = branch(other).properties.keys - branch(part).properties.keys
        base = {"type" => scope_schema["type"]}.merge(branch(part).documentation, scope_schema.except("description"))
        base["properties"] = variant_properties(scope_schema, excluded)

        variant = Conjunction.call([base, branch(part).to_schema])

        if part == :then
          given.holds_in?(variant) ? variant : Conjunction.conjoin(variant, given.to_schema(in_given: true))
        else
          given.fails_in?(variant) ? variant : variant.merge("not" => given.to_schema(in_given: true))
        end
      end

      # Lists the properties of a variant
      #
      # The excluded names are dropped. When the scope allows additional
      # properties, they are forbidden with a `false` schema instead.
      #
      # @param scope_schema [Hash] The scope schema with every property listed
      # @param excluded [Array<String>] The names only the other branch declares
      # @return [Hash] The variant properties
      def variant_properties(scope_schema, excluded)
        properties = scope_schema["properties"].except(*excluded)
        return properties if scope_schema["additionalProperties"] == false

        properties.merge(excluded.to_h { |property_name| [property_name, false] })
      end

      # @return [String] The condition name for error messages
      def label
        name ? "Condition '#{name}'" : "Condition"
      end
    end
  end
end

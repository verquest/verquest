# frozen_string_literal: true

module Verquest
  # DSL class methods for conditional schemas (`if` / `then` / `else`)
  #
  # `condition` opens a {Verquest::Conditions::Condition} on the current scope.
  # `given`, `then_apply` and `else_apply` make its parts the current scope, so
  # `field`, `object` and the rest add branch properties exactly as they add
  # regular ones, and the rule methods add rules.
  #
  # @example
  #   version "2025-09" do
  #     field :kind, type: :string
  #
  #     condition :company do
  #       given { equals :kind, "company" }
  #       then_apply { field :vat_id, type: :string, required: true }
  #     end
  #   end
  #
  # @api private
  module Base::ConditionClassMethods
    private

    # Declares a condition on the current scope
    #
    # @param name [Symbol, nil] Optional name, used to exclude the condition in a later version
    # @param document_as [Symbol, nil] `:one_of` to document the condition as a oneOf of its branches
    #   in `to_schema`, while validation keeps `if` / `then` / `else`. Only for a condition in a version.
    # @yield Block declaring `given`, `then_apply` and `else_apply`
    # @return [void]
    # @raise [ArgumentError] If the current scope can't hold conditions, or document_as is used outside a version
    def condition(name = nil, document_as: nil, &block)
      raise ArgumentError, "condition can only be declared in a version, object or inline collection" unless current_scope.respond_to?(:add_condition)
      raise ArgumentError, "document_as: :one_of can only be used on a condition in a version" if document_as && !current_scope.is_a?(Version)

      condition = Conditions::Condition.new(name:, document_as:)
      current_scope.add_condition(condition)
      within_scope(condition, &block)
    end

    # Declares the `if` of the current condition
    #
    # @yield Block declaring rules
    # @return [void]
    def given(&block)
      open_condition_part(:given, &block)
    end

    # Declares the `then` of the current condition
    #
    # The title, description and deprecated flag document the branch's
    # variant when the condition is declared with `document_as: :one_of`.
    #
    # @param title [String, nil] Title of the branch's oneOf variant
    # @param description [String, nil] Description of the branch's oneOf variant
    # @param deprecated [Boolean, nil] Whether the branch's oneOf variant is deprecated
    # @yield Block declaring rules and properties
    # @return [void]
    def then_apply(title: nil, description: nil, deprecated: nil, &block)
      open_condition_part(:then, title:, description:, deprecated:, &block)
    end

    # Declares the `else` of the current condition
    #
    # The title, description and deprecated flag document the branch's
    # variant when the condition is declared with `document_as: :one_of`.
    #
    # @param title [String, nil] Title of the branch's oneOf variant
    # @param description [String, nil] Description of the branch's oneOf variant
    # @param deprecated [Boolean, nil] Whether the branch's oneOf variant is deprecated
    # @yield Block declaring rules and properties
    # @return [void]
    def else_apply(title: nil, description: nil, deprecated: nil, &block)
      open_condition_part(:else, title:, description:, deprecated:, &block)
    end

    # Declares a condition that applies the block when a property is present
    #
    # Shorthand for `condition(name) { given { present key }; then_apply { ... } }`.
    #
    # @param key [Symbol] The property whose presence triggers the block
    # @param name [Symbol, nil] Optional condition name
    # @yield Block declaring rules and properties, like `then_apply`
    # @return [void]
    def depends_on(key, name = nil, &block)
      condition(name) do
        given { present key }
        then_apply(&block)
      end
    end

    # Removes inherited named conditions from the current version
    #
    # A named condition can be declared only once per version, so exclude an
    # inherited one before declaring a condition with the same name.
    #
    # @param names [Array<Symbol>] The condition names
    # @return [void]
    # @raise [ArgumentError] If a condition is not defined
    def exclude_conditions(*names)
      names.each { |name| current_scope.remove_condition(name) }
    end

    # Requires the named properties to be present
    #
    # @param names [Array<Symbol>] The property names
    # @return [void]
    def present(*names)
      add_rule(Conditions::Rules::Present.new(names))
    end

    # Forbids the named properties
    #
    # @param names [Array<Symbol>] The property names
    # @return [void]
    def absent(*names)
      add_rule(Conditions::Rules::Absent.new(names))
    end

    # Requires a property to hold one value
    #
    # @param name [Symbol] The property name
    # @param value [Object] The value
    # @return [void]
    def equals(name, value)
      add_rule(Conditions::Rules::Equals.new(name, value))
    end

    # Requires a property to hold one of several values
    #
    # @param name [Symbol] The property name
    # @param values [Array] The values
    # @return [void]
    def value_in(name, values)
      add_rule(Conditions::Rules::ValueIn.new(name, values))
    end

    # Requires a property to match schema options (camelized like field options)
    #
    # @param name [Symbol] The property name
    # @param schema_options [Hash] The schema options
    # @return [void]
    def satisfies(name, **schema_options)
      add_rule(Conditions::Rules::Satisfies.new(name, camelize(schema_options)))
    end

    # Requires at least one of the rules in the block to hold
    #
    # @yield Block declaring the alternative rules
    # @return [void]
    def any(&block)
      add_rule_set(Conditions::Rules::Any.new, &block)
    end

    # Requires none of the rules in the block to hold
    #
    # @yield Block declaring the rules
    # @return [void]
    def none(&block)
      add_rule_set(Conditions::Rules::None.new, &block)
    end

    # Makes a part of the current condition the scope for the block
    #
    # @param part [Symbol] :given, :then or :else
    # @yield Block declaring the part
    # @return [void]
    # @raise [ArgumentError] If the current scope is not a condition
    def open_condition_part(part, **options, &block)
      raise ArgumentError, "given, then_apply and else_apply can only be used inside a condition" unless current_scope.is_a?(Conditions::Condition)

      within_scope(current_scope.open(part, **options), &block)
    end

    # Adds a rule to the current scope
    #
    # @param rule [#to_schema, #property_names] The rule
    # @return [void]
    # @raise [ArgumentError] If the current scope can't hold rules
    def add_rule(rule)
      raise ArgumentError, "Rules can only be used inside given, then_apply, else_apply, depends_on, any or none" unless current_scope.respond_to?(:add_rule)

      current_scope.add_rule(rule)
    end

    # Adds a rule that holds other rules and makes it the scope for the block
    #
    # @param rule_set [Verquest::Conditions::Rules::Any] The rule
    # @yield Block declaring the nested rules
    # @return [void]
    def add_rule_set(rule_set, &block)
      add_rule(rule_set)
      within_scope(rule_set, &block)
    end

    # Runs the block with another current scope
    #
    # @param scope [Object] The scope for the block
    # @yield Block evaluated in the class context
    # @return [void]
    def within_scope(scope, &block)
      previous_scope = current_scope
      @current_scope = scope

      instance_exec(&block)
    ensure
      @current_scope = previous_scope
    end
  end
end

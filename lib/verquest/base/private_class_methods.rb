# frozen_string_literal: true

module Verquest
  # Private class methods for Verquest::Base
  #
  # This module contains internal class methods used by the versioning system
  # that are not intended for direct use by client code.
  #
  # @api private
  module Base::PrivateClassMethods
    # Resolves the version to use, either from the provided version,
    # configuration's current_version, or raises an error if none is available
    #
    # @param version [String, nil] The specific version to resolve
    # @return [Verquest::Version] The resolved version object
    # @raise [ArgumentError] If no version is provided and no current_version is configured
    # @raise [Verquest::VersionNotFoundError] If no version matches, or supported_versions leaves the version out
    # @raise [Verquest::DefinitionError] If supported_versions max sorts before every declared version
    def resolve(version)
      if version.nil? && Verquest.configuration.current_version
        version = instance_exec(&Verquest.configuration.current_version)
      elsif version.nil?
        raise ArgumentError, "Version must be provided or set by Verquest.configuration.current_version"
      end

      check_supported_version!(version)
      versions.resolve(version)
    end

    # Returns the range declared with supported_versions on this class or its closest superclass
    #
    # @return [Verquest::SupportedVersions, nil] The range, or nil when the request serves every declared version
    def supported_version_range
      return @supported_versions if defined?(@supported_versions)

      superclass.supported_version_range if superclass.respond_to?(:supported_version_range)
    end

    private

    # @return [Verquest::Version, Verquest::Properties::Object] The current scope being defined
    attr_reader :current_scope

    # @return [Hash] Default options for property definitions
    # Default options used when using teh with_options method.
    attr_reader :default_options

    # Returns the versions container, initializing it if needed
    #
    # @return [Verquest::Versions] The versions container
    def versions
      @versions ||= Versions.new
    end

    # Limits the versions this request serves
    #
    # Resolving a version outside the range raises {Verquest::VersionNotFoundError}. Subclasses
    # inherit the range; calling it without arguments removes an inherited one.
    #
    # @example
    #   supported_versions min: "2025-09", max: "2026-03"
    #
    # @param min [String, nil] The first supported version (inclusive), defaults to the first declared version
    # @param max [String, nil] The last supported version (inclusive), defaults to no upper bound
    # @return [void]
    # @raise [Verquest::DefinitionError] If min sorts after max, or a version is already defined
    def supported_versions(min: nil, max: nil)
      raise DefinitionError, "supported_versions must be set before the first version" if current_scope

      @supported_versions = (min.nil? && max.nil?) ? nil : SupportedVersions.new(min:, max:)
    end

    # Raises unless supported_versions covers the requested version (declared blocks may lie outside it)
    #
    # @param version [String] The requested version
    # @return [void]
    # @raise [Verquest::VersionNotFoundError] If the version is outside the range
    # @raise [Verquest::DefinitionError] If max sorts before every declared version
    def check_supported_version!(version)
      range = supported_version_range
      return unless range

      declared = versions.names
      range.check!(declared, name || inspect)
      return if declared.empty? || range.covers?(version.to_s)

      raise VersionNotFoundError, "Version '#{version}' is outside supported_versions (#{range}) of #{name || inspect}"
    end

    # Defines a new version with optional inheritance from another version
    #
    # @param name [String] The name/identifier of the version
    # @param inherit [Boolean, String] Whether to inherit from current scope or specific version name
    # @param exclude_properties [Array<Symbol>] Properties to exclude when inheriting
    # @yield Block defining the version's structure and properties
    # @return [void]
    def version(name, inherit: true, exclude_properties: [], &block)
      version = Version.new(name:, location:)
      versions.add(version)

      if inherit && @current_scope
        version.copy_from(@current_scope, exclude_properties:)
      elsif inherit.is_a?(String)
        inherit_version = versions.resolve(inherit)
        version.copy_from(inherit_version, exclude_properties:)
      end

      @default_options = {}
      @current_scope = version

      instance_exec(&block)
    ensure
      version.description ||= versions.description
      version.schema_options = versions.schema_options.merge(version.schema_options).transform_keys(&:to_s)
      version.prepare
    end

    # Sets the description for the current version scope or globally
    #
    # @param text [String] The description text
    # @return [void]
    # @raise [RuntimeError] If called outside of a version scope
    def description(text)
      if current_scope.nil?
        versions.description = text
      elsif current_scope.is_a?(Version)
        current_scope.description = text
      else
        raise "Description can only be set within a version scope or globally"
      end
    end

    # Sets additional schema options for the current version scope or globally
    #
    # @param schema_options [Hash] The schema options to set
    # @return [void]
    # @raise [RuntimeError] If called outside of a version scope
    def schema_options(**schema_options)
      camelize(schema_options)

      if current_scope.nil?
        versions.schema_options.merge!(schema_options)
      elsif current_scope.is_a?(Version)
        current_scope.schema_options.merge!(schema_options)
      else
        raise "Additional properties can only be set within a version scope or globally"
      end
    end

    # Executes the given block with the specified options, temporarily overriding
    # the default options for the duration of the block
    #
    # @param options [Hash] The options to set during the block execution
    # @yield Block to be executed with the temporary options
    # @return [void]
    def with_options(**options, &block)
      camelize(options)

      original_options = default_options
      @default_options = options.except(:map)

      instance_exec(&block)
    ensure
      @default_options = original_options
    end

    # Defines a new field for the current version scope
    #
    # @param name [Symbol] The name of the field
    # @param type [Symbol] The data type of the field
    # @param map [String, nil] An optional mapping to another field
    # @param required [Boolean, Array<Symbol>] Whether the field is required
    # @param nullable [Boolean] Whether the field can be null
    # @param schema_options [Hash] Additional schema options for the field
    # @param parameter_examples [Hash, nil] Named OpenAPI Example Objects for the query parameter (query requests only)
    # @return [void]
    def field(name, type: nil, map: nil, required: nil, nullable: nil, parameter_examples: nil, **schema_options)
      camelize(schema_options)

      type = default_options.fetch(:type, type)
      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?
      schema_options = default_options.except(:type, :required, :nullable).merge(schema_options)

      field = Properties::Field.new(name:, type:, map:, required:, nullable:, **schema_options)
      add_property(field, parameter_examples)
    end

    # Defines a new enum property for the current version scope
    #
    # @param name [Symbol] The name of the enum
    # @param values [Array] The possible values for the enum
    # @param map [String, nil] An optional mapping to another property
    # @param required [Boolean, Array<Symbol>] Whether the enum is required
    # @param nullable [Boolean] Whether the enum can be null
    # @param schema_options [Hash] Additional schema options for the enum
    # @param parameter_examples [Hash, nil] Named OpenAPI Example Objects for the query parameter (query requests only)
    # @return [void]
    def enum(name, values:, map: nil, required: nil, nullable: nil, parameter_examples: nil, **schema_options)
      camelize(schema_options)

      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?
      schema_options = default_options.except(:required, :nullable).merge(schema_options)

      enum_property = Properties::Enum.new(name:, values:, map:, required:, nullable:, **schema_options)
      add_property(enum_property, parameter_examples)
    end

    # Defines a new constant property for the current version scope
    #
    # @param name [Symbol] The name of the constant
    # @param value [Object] The value of the constant
    # @param map [String, nil] An optional mapping to another constant
    # @param required [Boolean, Array<Symbol>] Whether the constant is required
    # @param nullable [Boolean] Whether the constant can be null
    # @param schema_options [Hash] Additional schema options for the constant
    # @param parameter_examples [Hash, nil] Named OpenAPI Example Objects for the query parameter (query requests only)
    # @return [void]
    def const(name, value:, map: nil, required: nil, nullable: nil, parameter_examples: nil, **schema_options)
      camelize(schema_options)
      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?

      const = Properties::Const.new(name:, value:, map:, required:, nullable:, **schema_options)
      add_property(const, parameter_examples)
    end

    # Defines a new object for the current version scope
    #
    # @param name [Symbol] The name of the object
    # @param map [String, nil] An optional mapping to another object
    # @param required [Boolean, Array<Symbol>] Whether the object is required
    # @param nullable [Boolean] Whether the object can be null
    # @param schema_options [Hash] Additional schema options for the object
    # @param parameter_examples [Hash, nil] Named OpenAPI Example Objects for the query parameter (query requests only)
    # @yield Block executed in the context of the new object definition
    # @return [void]
    def object(name, map: nil, required: nil, nullable: nil, parameter_examples: nil, **schema_options, &block)
      unless block_given?
        raise ArgumentError, "a block must be given to define the object"
      end

      camelize(schema_options)
      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?
      schema_options = default_options.except(:type, :required, :nullable).merge(schema_options)

      object = Properties::Object.new(name:, map:, required:, nullable:, **schema_options)
      add_property(object, parameter_examples)

      if block_given?
        previous_scope = current_scope
        @current_scope = object

        instance_exec(&block)
      end
    ensure
      @current_scope = previous_scope if block_given?
    end

    # Defines a new collection for the current version scope
    #
    # @param name [Symbol] The name of the collection
    # @param item [Class, nil] The item type in the collection
    # @param required [Boolean, Array<Symbol>] Whether the collection is required
    # @param nullable [Boolean] Whether the collection can be null
    # @param map [String, nil] An optional mapping to another collection
    # @param schema_options [Hash] Additional schema options for the collection
    # @yield Block executed in the context of the new collection definition
    # @return [void]
    # @raise [ArgumentError] without item: or a block, or when item does not respond to to_ref
    def collection(name, item: nil, required: nil, nullable: nil, map: nil, **schema_options, &block)
      if item.nil? && !block_given?
        raise ArgumentError, "item must be provided or a block must be given to define the collection"
      elsif !item.nil? && !item.respond_to?(:to_ref)
        raise ArgumentError, "item must be a Verquest::Base subclass or respond to to_ref and to_validation_schema"
      end

      camelize(schema_options)
      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?
      schema_options = default_options.except(:required, :nullable).merge(schema_options)

      collection = Properties::Collection.new(name:, item:, required:, nullable:, map:, **schema_options)
      current_scope.add(collection)

      if block_given?
        previous_scope = current_scope
        @current_scope = collection

        instance_exec(&block)
      end
    ensure
      @current_scope = previous_scope if block_given?
    end

    # Defines a new reference for the current version scope
    #
    # @param name [Symbol] The name of the reference
    # @param from [Verquest::Base] The source of the reference
    # @param property [Symbol, nil] An optional specific property to reference
    # @param map [String, nil] An optional mapping to another reference
    # @param required [Boolean, Array<Symbol>] Whether the reference is required
    # @param nullable [Boolean] Whether this reference can be null
    # @param parameter_examples [Hash, nil] Named OpenAPI Example Objects for the query parameter (query requests only)
    # @return [void]
    def reference(name, from:, property: nil, map: nil, required: nil, nullable: nil, parameter_examples: nil)
      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?

      reference = Properties::Reference.new(name:, from:, property:, map:, required:, nullable:)
      add_property(reference, parameter_examples)
    end

    # Defines a new array property for the current version scope
    #
    # @param name [Symbol] The name of the array property
    # @param type [Symbol] The data type of the array elements
    # @param required [Boolean, Array<Symbol>] Whether the array property is required
    # @param nullable [Boolean] Whether this array can be null
    # @param map [String, nil] An optional mapping to another array property
    # @param explode [Boolean, nil] In query requests, whether items are sent as repeated keys (true) or comma-separated (false); nil uses the configuration
    # @param item_schema_options [Hash] Additional JSON schema options for the array items (merged with custom type options)
    # @param schema_options [Hash] Additional schema options for the array property
    # @param parameter_examples [Hash, nil] Named OpenAPI Example Objects for the query parameter (query requests only)
    # @return [void]
    def array(name, type:, required: nil, nullable: nil, map: nil, explode: nil, parameter_examples: nil, item_schema_options: {}, **schema_options)
      camelize(schema_options)

      type = default_options.fetch(:type, type)
      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?
      schema_options = default_options.except(:type, :required, :nullable).merge(schema_options)

      array = Properties::Array.new(name:, type:, required:, nullable:, map:, explode:, item_schema_options:, **schema_options)
      add_property(array, parameter_examples)
    end

    # Defines a oneOf property for polymorphic schemas
    #
    # Creates a JSON Schema oneOf structure where exactly one of the defined
    # schemas must match. When used at the root level (without a name), it creates
    # a "combination schema" where the entire request body matches one of the options.
    #
    # @param name [Symbol, nil] The property name, or nil for root-level oneOf
    # @param discriminator [Symbol, nil] The property used to discriminate between schemas
    # @param required [Boolean, Array<Symbol>, nil] Whether this property is required
    # @param nullable [Boolean] Whether this property can be null
    # @param map [String, nil] An optional mapping to another property
    # @yield Block defining the schema options using reference declarations
    # @return [void]
    def one_of(name: nil, discriminator: nil, required: nil, nullable: nil, map: nil, &block)
      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?

      one_of = Properties::OneOf.new(name:, discriminator:, required:, nullable:, map:)
      current_scope.add(one_of)

      if block_given?
        previous_scope = current_scope
        @current_scope = one_of

        instance_exec(&block)
      end
    ensure
      @current_scope = previous_scope if block_given?
    end

    # Adds a property to the current scope
    #
    # @param property [Verquest::Properties::Base] The property to add
    # @param parameter_examples [Hash, nil] Named OpenAPI Example Objects for the query parameter
    # @return [void]
    def add_property(property, parameter_examples)
      property.parameter_examples = parameter_examples
      current_scope.add(property)
    end

    # Excludes specified properties from the current scope by removing them
    # from the version's property set
    #
    # @param names [Array<Symbol>] The names of the properties to exclude
    # @return [void]
    def exclude_properties(*names)
      names.each do |name|
        current_scope.remove(name)
      end
    end
  end
end

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
    def resolve(version)
      if version.nil? && Verquest.configuration.current_version
        version = instance_exec(&Verquest.configuration.current_version)
      elsif version.nil?
        raise ArgumentError, "Version must be provided or set by Verquest.configuration.current_version"
      end

      versions.resolve(version)
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

    # Defines a new version with optional inheritance from another version
    #
    # @param name [String] The name/identifier of the version
    # @param inherit [Boolean, String] Whether to inherit from current scope or specific version name
    # @param exclude_properties [Array<Symbol>] Properties to exclude when inheriting
    # @yield Block defining the version's structure and properties
    # @return [void]
    def version(name, inherit: true, exclude_properties: [], &block)
      version = Version.new(name:)
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
    # @return [void]
    def field(name, type: nil, map: nil, required: nil, nullable: nil, **schema_options)
      camelize(schema_options)

      type = default_options.fetch(:type, type)
      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?
      schema_options = default_options.except(:type, :required, :nullable).merge(schema_options)

      field = Properties::Field.new(name:, type:, map:, required:, nullable:, **schema_options)
      current_scope.add(field)
    end

    # Defines a new enum property for the current version scope
    #
    # @param name [Symbol] The name of the enum
    # @param values [Array] The possible values for the enum
    # @param map [String, nil] An optional mapping to another property
    # @param required [Boolean, Array<Symbol>] Whether the enum is required
    # @param nullable [Boolean] Whether the enum can be null
    # @param schema_options [Hash] Additional schema options for the enum
    # @return [void]
    def enum(name, values:, map: nil, required: nil, nullable: nil, **schema_options)
      camelize(schema_options)

      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?
      schema_options = default_options.except(:required, :nullable).merge(schema_options)

      enum_property = Properties::Enum.new(name:, values:, map:, required:, nullable:, **schema_options)
      current_scope.add(enum_property)
    end

    # Defines a new constant property for the current version scope
    #
    # @param name [Symbol] The name of the constant
    # @param value [Object] The value of the constant
    # @param map [String, nil] An optional mapping to another constant
    # @param required [Boolean, Array<Symbol>] Whether the constant is required
    # @param schema_options [Hash] Additional schema options for the constant
    # @return [void]
    def const(name, value:, map: nil, required: nil, **schema_options)
      camelize(schema_options)
      required = default_options.fetch(:required, false) if required.nil?

      const = Properties::Const.new(name:, value:, map:, required:, **schema_options)
      current_scope.add(const)
    end

    # Defines a new object for the current version scope
    #
    # @param name [Symbol] The name of the object
    # @param map [String, nil] An optional mapping to another object
    # @param required [Boolean, Array<Symbol>] Whether the object is required
    # @param nullable [Boolean] Whether the object can be null
    # @param schema_options [Hash] Additional schema options for the object
    # @yield Block executed in the context of the new object definition
    # @return [void]
    def object(name, map: nil, required: nil, nullable: nil, **schema_options, &block)
      unless block_given?
        raise ArgumentError, "a block must be given to define the object"
      end

      camelize(schema_options)
      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?
      schema_options = default_options.except(:type, :required, :nullable).merge(schema_options)

      object = Properties::Object.new(name:, map:, required:, nullable:, **schema_options)
      current_scope.add(object)

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
    def collection(name, item: nil, required: nil, nullable: nil, map: nil, **schema_options, &block)
      if item.nil? && !block_given?
        raise ArgumentError, "item must be provided or a block must be given to define the collection"
      elsif !item.nil? && !block_given? && !(item <= Verquest::Base)
        raise ArgumentError, "item must be a child of Verquest::Base class or nil" unless type.is_a?(Verquest::Properties::Base)
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
    # @return [void]
    def reference(name, from:, property: nil, map: nil, required: nil, nullable: nil)
      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?

      reference = Properties::Reference.new(name:, from:, property:, map:, required:, nullable:)
      current_scope.add(reference)
    end

    # Defines a new array property for the current version scope
    #
    # @param name [Symbol] The name of the array property
    # @param type [Symbol] The data type of the array elements
    # @param required [Boolean, Array<Symbol>] Whether the array property is required
    # @param nullable [Boolean] Whether this array can be null
    # @param map [String, nil] An optional mapping to another array property
    # @param schema_options [Hash] Additional schema options for the array property
    # @return [void]
    def array(name, type:, required: nil, nullable: nil, map: nil, **schema_options)
      camelize(schema_options)

      type = default_options.fetch(:type, type)
      required = default_options.fetch(:required, false) if required.nil?
      nullable = default_options.fetch(:nullable, false) if nullable.nil?
      schema_options = default_options.except(:type, :required, :nullable).merge(schema_options)

      array = Properties::Array.new(name:, type:, required:, nullable:, map:, **schema_options)
      current_scope.add(array)
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

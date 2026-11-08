# frozen_string_literal: true

module Verquest
  # Public class methods to be included in Verquest::Base
  #
  # This module contains class methods that handle parameter mapping, schema generation,
  # and validation functionality for Verquest API request objects.
  module Base::PublicClassMethods
    # Where request params can come from
    LOCATIONS = %i[body query path].freeze

    # Maps incoming parameters to the appropriate structure based on version mapping
    #
    # @param params [Hash] The parameters to be mapped
    # @param version [String, nil] Specific version to use, defaults to configuration setting
    # @param validate [Boolean, nil] Whether to validate the params, defaults to configuration setting
    # @param remove_extra_root_keys [Boolean, nil] Whether to remove extra keys at the root level, defaults to configuration setting
    # @param reject_other_version_keys [Boolean, nil] Whether to report root keys only another version declares as validation errors (only when validating), defaults to configuration setting
    # @return [Verquest::Result, Hash] When validation_error_handling is :result, returns a Success result with mapped params or Failure result with validation errors.
    #   When validation_error_handling is :raise, returns mapped params directly or raises InvalidParamsError with validation errors.
    def process(params, version: nil, validate: nil, remove_extra_root_keys: nil, reject_other_version_keys: nil)
      validate = Verquest.configuration.validate_params if validate.nil?
      remove_extra_root_keys = Verquest.configuration.remove_extra_root_keys if remove_extra_root_keys.nil?
      reject_other_version_keys = Verquest.configuration.reject_other_version_keys if reject_other_version_keys.nil?

      version_class = resolve(version)

      params = params.dup
      params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)

      if validate && reject_other_version_keys && (other_version_errors = other_version_key_errors(params, version_class)).any?
        return validation_failure(other_version_errors)
      end

      params = params.slice(*version_class.all_properties.keys) if remove_extra_root_keys && !version_class.combination?
      params = version_class.coerce_params(params)
      params = copy_params(params) if validate && version_class.inserts_property_defaults?

      if validate && (validation_result = version_class.validate_params(params: params)) && validation_result.any?
        validation_failure(validation_result)
      else
        begin
          mapped_params = version_class.map_params(params)

          case Verquest.configuration.validation_error_handling
          when :raise
            mapped_params
          when :result
            Result.success(mapped_params)
          end
        rescue MappingError => e
          case Verquest.configuration.validation_error_handling
          when :raise
            raise
          when :result
            Result.failure([{message: e.message, type: "mapping_error"}])
          end
        end
      end
    end

    # Returns the names of the filters the version declares
    #
    # @param version [String, nil] Specific version to use, defaults to configuration setting
    # @return [Array<String>] Filter names in declaration order
    def filter_names(version: nil)
      resolve(version).filters.keys
    end

    # Filters a target with the version's filters
    #
    # Runs the filter blocks in declaration order. Each block gets the previous block's result and the
    # value of its property in params; a filter whose value is nil or empty is skipped.
    #
    # @example
    #   params = DealsQuery.process(request.query_parameters)
    #   DealsQuery.apply_filters(Deal.all, params)
    #
    # @param target [Object] What to filter, such as an ActiveRecord relation
    # @param params [Hash{String => Object}] Processed params with String keys, as {#process} returns them (the
    #   result's `value` when validation_error_handling is :result); Symbol keys aren't read
    # @param version [String, nil] Specific version to use, defaults to configuration setting
    # @return [Object] The filtered target
    def apply_filters(target, params, version: nil)
      resolve(version).filters.reduce(target) do |filtered, (name, block)|
        value = params[name]
        next filtered if value.nil? || (value.respond_to?(:empty?) && value.empty?)

        block.call(filtered, value)
      end
    end

    # Sets or returns where the request's params come from
    #
    # A query request (`location :query`) or path request (`location :path`)
    # converts strings to the types its schema expects before validating them,
    # and documents its properties with {#to_parameters}. Subclasses inherit
    # the location.
    #
    # @example
    #   class ListQuery < Verquest::Base
    #     location :query
    #
    #     version "2025-06" do
    #       field :page, type: :integer
    #     end
    #   end
    #
    # @param value [Symbol, nil] `:body`, `:query` or `:path` to set the location, nil to return it
    # @return [Symbol] The location, `:body` unless set on this class or a superclass
    # @raise [ArgumentError] If the value is not a known location, or a version is already defined
    def location(value = nil)
      return @location || (superclass.respond_to?(:location) ? superclass.location : :body) if value.nil?

      raise ArgumentError, "Location must be one of #{LOCATIONS.join(", ")}" unless LOCATIONS.include?(value)
      raise ArgumentError, "Location must be set before the first version" if current_scope

      @location = value
    end

    # Returns OpenAPI parameter objects for a query or path request
    #
    # One parameter per property, with symbol keys, ready for rswag's `parameter`.
    # Schemas are inlined, arrays get `style: :form` and their explode value, and
    # objects get `style: :deepObject`.
    #
    # @example
    #   ListQuery.to_parameters(version: "2025-06").each { |p| parameter(p) }
    #
    # @param version [String, nil] Specific version to use, defaults to configuration setting
    # @return [Array<Hash>] The OpenAPI parameter objects
    # @raise [ArgumentError] If the request is a body request
    def to_parameters(version: nil)
      raise ArgumentError, "#{name} has no parameters (location #{location.inspect})" if location == :body

      resolve(version).parameters
    end

    # Returns the JSON schema for the request
    #
    # @param version [String, nil] Specific version to use, defaults to configuration setting
    # @return [Hash] The JSON schema for the request
    def to_schema(version: nil)
      resolve(version).schema
    end

    # Returns the validation JSON schema for the request or a specific property. It contains all schemas from references.
    #
    # @param version [String, nil] Specific version to use, defaults to configuration setting
    # @param property [Symbol, nil] Specific property to retrieve schema for
    # @return [Hash] The validation schema or property schema
    def to_validation_schema(version: nil, property: nil)
      version = resolve(version)

      if property
        version.validation_schema["properties"][property.to_s]
      else
        version.validation_schema
      end
    end

    # Validates the generated JSON schema structure
    #
    # Under `:openapi30` it checks the document from `to_schema`, otherwise the validation schema.
    #
    # @param version [String, nil] Specific version to use, defaults to configuration setting
    # @return [Boolean] True if schema is valid
    def valid_schema?(version: nil)
      resolve(version).valid_schema?
    end

    # Validates the schema against the metaschema and returns detailed validation errors
    #
    # This method validates the schema against the configured JSON Schema metaschema
    # and returns detailed validation errors if any are found. It's useful for debugging
    # schema issues during development and testing. Under `:openapi30` it checks the document from `to_schema`, so
    # the pointers refer to it.
    #
    # @param version [String, nil] Specific version to use, defaults to configuration setting
    # @return [Array<Hash>] An array of validation error details, empty if schema is valid
    # @see #valid_schema?
    def validate_schema(version: nil)
      resolve(version).validate_schema
    end

    # Returns the mapping for a specific version or property
    #
    # @param version [String, nil] Specific version to use, defaults to configuration setting
    # @param property [String, Symbol, nil] Specific property to retrieve mapping for
    # @return [Hash] The mapping configuration
    def mapping(version: nil, property: nil)
      version = resolve(version)

      if property
        version.mapping_for(property)
      else
        version.mapping
      end
    end

    # Returns the external mapping for a specific version
    #
    # This method returns a mapping hash that translates from internal attribute names back to external parameter names.
    #
    # @param version [String, nil] Specific version to use, defaults to configuration setting
    # @return [Hash] The inverted mapping configuration where keys are internal names and values are external names
    # @see #mapping
    def external_mapping(version: nil)
      version = resolve(version)
      version.external_mapping
    end

    # Returns the JSON reference for the request or a specific property
    #
    # @param property [String, Symbol, nil] Specific property to retrieve reference for
    # @return [String] The JSON reference for the request or property
    def to_ref(property: nil)
      base = "#/components/schemas/#{component_name}"

      property ? "#{base}/properties/#{property}" : base
    end

    # Returns the component name derived from the class name. It is used in JSON schema references.
    #
    # @return [String] The component name
    def component_name
      name.to_s.split("::", 2).last.tr("::", "")
    end
  end
end

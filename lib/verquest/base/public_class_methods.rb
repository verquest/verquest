# frozen_string_literal: true

module Verquest
  # Public class methods to be included in Verquest::Base
  #
  # This module contains class methods that handle parameter mapping, schema generation,
  # and validation functionality for Verquest API request objects.
  module Base::PublicClassMethods
    # Maps incoming parameters to the appropriate structure based on version mapping
    #
    # @param params [Hash] The parameters to be mapped
    # @param version [String, nil] Specific version to use, defaults to configuration setting
    # @param validate [Boolean, nil] Whether to validate the params, defaults to configuration setting
    # @param remove_extra_root_keys [Boolean, nil] Whether to remove extra keys at the root level, defaults to configuration setting
    # @return [Verquest::Result, Hash, Exception] When validation_error_handling is :result, returns a Success result with mapped params or Failure result with validation errors.
    #   When validation_error_handling is :raise, returns mapped params directly or raises InvalidParamsError with validation errors.
    def process(params, version: nil, validate: nil, remove_extra_root_keys: nil)
      validate = Verquest.configuration.validate_params if validate.nil?
      remove_extra_root_keys = Verquest.configuration.remove_extra_root_keys if remove_extra_root_keys.nil?

      version_class = resolve(version)

      params = params.dup
      params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
      params = params.slice(*version_class.properties.keys) if remove_extra_root_keys

      if validate && (validation_result = version_class.validate_params(params: params)) && validation_result.any?
        case Verquest.configuration.validation_error_handling
        when :raise
          raise InvalidParamsError.new("Validation failed", errors: validation_result)
        when :result
          Result.failure(validation_result)
        end
      else
        mapped_params = version_class.map_params(params)

        case Verquest.configuration.validation_error_handling
        when :raise
          mapped_params
        when :result
          Result.success(mapped_params)
        end
      end
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
    # @param version [String, nil] Specific version to use, defaults to configuration setting
    # @return [Boolean] True if schema is valid
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

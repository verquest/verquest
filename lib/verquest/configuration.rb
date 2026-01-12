# frozen_string_literal: true

module Verquest
  # Configuration for the Verquest gem
  #
  # This class manages configuration settings for the Verquest gem, including
  # validation behavior, JSON Schema version, and version resolution strategy.
  # It's used to customize the behavior of versioned API requests.
  #
  # @example Basic configuration
  #   Verquest.configure do |config|
  #     config.validate_params = true
  #     config.current_version = -> { Current.api_version }
  #   end
  class Configuration
    include Base::HelperClassMethods

    # Mapping of supported JSON Schema versions to their implementation classes
    #
    # This constant maps the symbolic names of JSON Schema versions to their
    # corresponding JSONSchemer implementation classes. These are used for schema
    # validation and generation based on the configured schema version.
    #
    # @example Accessing a schema implementation
    #   schema_class = Verquest::Configuration::SCHEMAS[:draft2020_12]
    #
    # @return [Hash<Symbol, Class>] A frozen hash mapping schema version names to implementation classes
    SCHEMAS = {
      draft4: JSONSchemer::Draft4,
      draft6: JSONSchemer::Draft6,
      draft7: JSONSchemer::Draft7,
      draft2019_09: JSONSchemer::Draft201909,
      draft2020_12: JSONSchemer::Draft202012,
      openapi30: JSONSchemer::OpenAPI30,
      openapi31: JSONSchemer::OpenAPI31
    }.freeze

    # @!attribute [rw] validate_params
    #   Controls whether parameters are automatically validated against the schema
    #   @return [Boolean] true if validation is enabled, false otherwise
    #
    # @!attribute [rw] json_schema_version
    #   The JSON Schema draft version to use for validation and schema generation (see Configuration::SCHEMAS)
    #   @return [Symbol] The JSON Schema version (e.g., :draft2020_12, :draft2019_09, :draft7)
    #
    # @!attribute [rw] validation_error_handling
    #   Controls how errors during parameter processing are handled
    #   @return [Symbol] :raise to raise errors (default) or :result to return errors in the Result object
    #
    # @!attribute [rw] remove_extra_root_keys
    #   Controls if extra root keys not defined in the schema should be removed from the parameters
    #   @return [Boolean] true if extra keys should be removed, false otherwise
    #
    # @!attribute [rw] insert_property_defaults
    #   Controls whether default values defined in property schemas should be inserted when not provided during validation
    #   @return [Boolean] true if default values should be inserted, false otherwise
    #
    # @!attribute [rw] default_additional_properties
    #   Controls the default behavior for handling properties not defined in the schema
    #   @return [Boolean] false to disallow additional properties (default), true to allow them
    attr_accessor :validate_params, :json_schema_version, :validation_error_handling,
      :remove_extra_root_keys, :insert_property_defaults, :default_additional_properties

    # @!attribute [r] current_version
    #   A callable object that returns the current API version to use when not explicitly specified
    #   @return [#call] An object responding to call that determines the current version
    #
    # @!attribute [r] version_resolver
    #   The resolver used to map version strings/identifiers to version objects
    #   @return [#call] An object that responds to `call` for resolving versions
    #
    # @!attribute [r] custom_field_types
    #   Custom field types to extend the standard set of field types
    #   @return [Hash<Symbol, Hash>] Hash mapping field type names to their configuration
    attr_reader :current_version, :version_resolver, :custom_field_types

    # Initialize a new Configuration with default values
    #
    # @return [Configuration] A new configuration instance with default settings
    def initialize
      @validate_params = true
      @json_schema_version = :draft2020_12
      @validation_error_handling = :raise
      @remove_extra_root_keys = true
      @version_resolver = VersionResolver
      @insert_property_defaults = true
      @custom_field_types = {}
      @default_additional_properties = false
    end

    # Sets the current version strategy using a callable object
    #
    # @param current_version [#call] An object that returns the current version when called
    # @raise [ArgumentError] If the provided value doesn't respond to call
    # @return [#call] The callable object that was set
    def current_version=(current_version)
      raise ArgumentError, "The current_version must respond to a call method" unless current_version.respond_to?(:call)

      @current_version = current_version
    end

    # Sets the version resolver
    #
    # @param version_resolver [#call] An object with a call method for resolving versions
    # @raise [ArgumentError] If the provided resolver doesn't respond to call
    # @return [#call] The resolver that was set
    def version_resolver=(version_resolver)
      raise ArgumentError, "The version_resolver must respond to a call method" unless version_resolver.respond_to?(:call)

      @version_resolver = version_resolver
    end

    # Sets the custom field types
    #
    # This method allows defining custom field types beyond the default ones.
    # Custom field types can be used to extend validation with specific formats
    # or patterns. Each custom field type should include a base type and optional
    # schema validation options.
    #
    # @example Adding a phone number field type
    #   config.custom_field_types = {
    #     email: {
    #       type: "string",
    #       schema_options: {format: "email", pattern: /\A[^@\s]+@[^@.\s]+(\.[^@.\s]+)+\z/}
    #     },
    #     uuid: {
    #       type: "string",
    #       schema_options: {format: "uuid", pattern: /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/}
    #     }
    #   }
    #
    # @param custom_field_types [Hash] A hash mapping field type names to their configuration
    # @raise [ArgumentError] If the provided value isn't a Hash
    # @return [Hash<Symbol, Hash>] The processed custom field types hash with symbolized keys
    def custom_field_types=(custom_field_types)
      raise ArgumentError, "Custom field types must be a Hash" unless custom_field_types.is_a?(Hash)

      custom_field_types.delete_if { |k, _| Properties::Field::DEFAULT_TYPES.include?(k.to_s) }
      custom_field_types.each do |_, value|
        value[:schema_options] = camelize(value[:schema_options]) if value[:schema_options]
      end

      @custom_field_types = custom_field_types.transform_keys(&:to_sym)
    end

    # Gets the JSON Schema class based on the configured version
    #
    # @return [Class] The JSON Schema class matching the configured version
    # @raise [ArgumentError] If the configured json_schema_version is not supported
    def json_schema
      SCHEMAS[json_schema_version] || raise(ArgumentError, "Unsupported JSON Schema version: #{json_schema_version}")
    end

    # Gets the JSON Schema URI for the configured schema version
    #
    # @return [String] The base URI for the configured JSON Schema version
    def json_schema_uri
      json_schema::BASE_URI.to_s
    end
  end
end

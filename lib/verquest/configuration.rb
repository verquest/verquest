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
    # @!attribute [rw] validate_params
    #   Controls whether parameters are automatically validated against the schema
    #   @return [Boolean] true if validation is enabled, false otherwise
    #
    # @!attribute [rw] json_schema_version
    #   The JSON Schema draft version to use for validation and schema generation (see the json-schema gem)
    #   @return [Symbol] The JSON Schema version (e.g., :draft4, :draft5)
    #
    # @!attribute [rw] validation_error_handling
    #   Controls how errors during parameter processing are handled
    #   @return [Symbol] :raise to raise errors (default) or :result to return errors in the Result object
    #
    # @!attribute [rw] remove_extra_root_keys
    #   Controls if extra root keys not defined in the schema should be removed from the parameters
    #   @return [Boolean] true if extra keys should be removed, false otherwise
    attr_accessor :validate_params, :json_schema_version, :validation_error_handling, :remove_extra_root_keys

    # @!attribute [r] current_version
    #   A callable object that returns the current API version to use when not explicitly specified
    #   @return [#call] An object responding to call that determines the current version
    #
    # @!attribute [r] version_resolver
    #   The resolver used to map version strings/identifiers to version objects
    #   @return [#call] An object that responds to `call` for resolving versions
    attr_reader :current_version, :version_resolver

    # Initialize a new Configuration with default values
    #
    # @return [Configuration] A new configuration instance with default settings
    def initialize
      @validate_params = true
      @json_schema_version = :draft6
      @validation_error_handling = :raise # or :result
      @remove_extra_root_keys = true
      @version_resolver = VersionResolver
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
  end
end

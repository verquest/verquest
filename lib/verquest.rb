# frozen_string_literal: true

require "zeitwerk"
require "json-schema"

loader = Zeitwerk::Loader.new
loader.tag = File.basename(__FILE__, ".rb")
loader.push_dir(File.dirname(__FILE__))
loader.setup

# Verquest is a Ruby gem for versioning API requests
#
# Verquest allows you to define and manage versioned API request schemas,
# handle parameter mapping between different versions, validate incoming
# parameters against schemas, and generate documentation.
#
# @example Basic usage
#   class UserCreateRequest < Verquest::Base
#     description "User Create Request"
#     schema_options additional_properties: false
#
#     version "2025-06" do
#       field :email, type: :string, required: true, format: "email"
#       field :name, type: :string
#
#       object :address do
#         field :street, type: :string, map: "/address_street"
#         field :city, type: :string, required: true, map: "/address_city"
#         field :zip_code, type: :string, map: "/address_zip_code"
#       end
#     end
#
#     version "2025-08", exclude_properties: %i[name] do
#       field :name, type: :string, required: true
#     end
#   end
#
#   # Map and validate parameters for a specific version
#   result = UserCreateRequest.map(params, version: "2025-07", validate: true)
#
#   if result.success?
#     process_user(result.value)
#   else
#     handle_errors(result.errors)
#   end
#
# @see Verquest::Base Base class for creating versioned request schemas
# @see Verquest::Configuration Configuration options for Verquest
module Verquest
  # Base error class for all Verquest-related errors
  # @api public
  Error = Class.new(StandardError)

  # Error raised when a requested version cannot be found
  # @api public
  VersionNotFoundError = Class.new(Verquest::Error)

  # Error raised when a requested property cannot be found in a version
  # @api public
  PropertyNotFoundError = Class.new(Verquest::Error)

  # Error raised when there are issues with property mappings
  # @api public
  MappingError = Class.new(Verquest::Error)

  # Error raised when parameters do not match the expected schema
  # @api public
  InvalidParamsError = Class.new(Verquest::Error) do
    attr_reader :errors

    # @param message [String] error message
    # @param errors [Array] validation errors
    def initialize(message, errors:)
      super(message)
      @errors = errors
    end
  end

  class << self
    # Returns the global configuration for Verquest
    #
    # @return [Verquest::Configuration] The configuration instance
    # @see Verquest::Configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure Verquest with the given block
    #
    # @example
    #   Verquest.configure do |config|
    #     config.validate_params = true
    #     config.current_version = -> { "2023-06" }
    #   end
    #
    # @yield [configuration] The configuration instance
    # @yieldparam configuration [Verquest::Configuration] The configuration to modify
    # @return [void]
    def configure
      yield(configuration)
    end
  end
end

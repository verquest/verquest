# frozen_string_literal: true

module Verquest
  # Helper module for tests that need to modify configuration
  # Include this module and use with_configuration to safely modify settings
  module ConfigurationTestHelper
    # Executes a block with modified configuration settings,
    # automatically restoring them afterward
    #
    # @param settings [Hash] Configuration settings to modify
    # @yield The block to execute with modified configuration
    # @return [Object] The result of the block
    #
    # @example
    #   with_configuration(validation_error_handling: :result) do
    #     result = Request.process(params, version: "2025-06")
    #     assert_predicate result, :failure?
    #   end
    def with_configuration(**settings)
      original_values = {}
      config = Verquest.configuration

      settings.each do |key, value|
        original_values[key] = config.public_send(key)
        config.public_send(:"#{key}=", value)
      end

      yield
    ensure
      original_values.each do |key, value|
        # Some setters (like current_version) don't accept nil, so use instance_variable_set
        if value.nil?
          config.instance_variable_set(:"@#{key}", value)
        else
          config.public_send(:"#{key}=", value)
        end
      end
    end
  end
end

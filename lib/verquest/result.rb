# frozen_string_literal: true

module Verquest
  # A result object for operation outcomes
  #
  # Result represents the outcome of an operation in the Verquest gem,
  # particularly parameter mapping and validation operations. It follows
  # the Result pattern, providing a consistent interface for both successful
  # and failed operations, avoiding exceptions for control flow.
  #
  # @example Handling a successful result
  #   result = Verquest::Result.success(transformed_params)
  #   if result.success?
  #     process_params(result.value)
  #   end
  #
  # @example Handling a failed result
  #   result = Verquest::Result.failure(["Invalid email format"])
  #   if result.failure?
  #     display_errors(result.errors)
  #   end
  class Result
    # @!attribute [r] success
    #   @return [Boolean] Whether the operation was successful
    #
    # @!attribute [r] value
    #   @return [Object, nil] The result value if successful, nil otherwise
    #
    # @!attribute [r] errors
    #   @return [Array] List of errors if failed, empty array otherwise
    attr_reader :success, :value, :errors

    # Initialize a new Result instance
    #
    # @param success [Boolean] Whether the operation was successful
    # @param value [Object, nil] The result value for successful operations
    # @param errors [Array, nil] List of errors for failed operations
    # @return [Result] A new Result instance
    def initialize(success:, value: nil, errors: nil)
      @success = success
      @value = value
      @errors = errors
    end

    # Create a successful result with a value
    #
    # @param value [Object] The successful operation's result value
    # @return [Result] A successful Result instance containing the value
    def self.success(value)
      new(success: true, value: value)
    end

    # Create a failed result with errors
    #
    # @param errors [Array, String] Error message(s) describing the failure
    # @return [Result] A failed Result instance containing the errors
    def self.failure(errors)
      new(success: false, errors: errors)
    end

    # Check if the result represents a successful operation
    #
    # @return [Boolean] true if the operation was successful, false otherwise
    def success?
      success
    end

    # Check if the result represents a failed operation
    #
    # @return [Boolean] true if the operation failed, false otherwise
    def failure?
      !success
    end
  end
end

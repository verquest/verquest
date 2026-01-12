# frozen_string_literal: true

module Verquest
  # HelperMethods module provides utility methods for Verquest
  module HelperMethods
    # Module that provides methods for working with required properties in schemas
    #
    # This module offers functionality to identify and categorize properties based on
    # their required status within schema definitions. It distinguishes between
    # unconditionally required properties (those marked with `required: true`) and
    # conditionally required properties (those with dependencies expressed as arrays).
    #
    # When included in classes that manage properties (like Version or Base property classes),
    # it provides methods to extract both types of required properties which can be used
    # for schema validation, documentation generation, or UI rendering.
    module RequiredProperties
      # Returns all properties that are unconditionally required
      #
      # This method identifies properties that must always be present in valid data,
      # by selecting those with their required attribute set to true (boolean).
      # Results are memoized to avoid recalculating on subsequent calls.
      #
      # @return [Array<String>] Names of properties marked as unconditionally required (required == true)
      def required_properties
        @_required_properties ||= properties.values.select { _1.required == true }.map(&:name)
      end

      # Returns properties that are conditionally required based on other properties
      #
      # This method identifies properties that are required only when certain other
      # properties are present. These are properties where the required attribute
      # is an array of dependency names rather than a boolean.
      # Results are memoized to avoid recalculating on subsequent calls.
      #
      # @return [Hash<String, Array<String>>] Hash mapping property names to their dependency arrays
      # @example Return value format:
      #   {
      #     "property_name1": ["dependency1", "dependency2"],
      #     "property_name2": ["dependency3"]
      #   }
      def dependent_required_properties
        @_dependent_required_properties ||= properties.values.select { _1.required.is_a?(Array) }.each_with_object({}) do |property, hash|
          hash[property.name] = property.required.map(&:to_s)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Verquest
  # Helper methods for Verquest::Base class methods
  #
  # This module contains utility methods for working with string and hash
  # transformations. It provides methods for converting between different
  # naming conventions (snake_case to camelCase) which is particularly useful
  # when working with JSON Schema properties.
  #
  # @api private
  module Base::HelperClassMethods
    # Converts hash keys from snake_case to camelCase format
    #
    # Transforms all keys in the given hash from snake_case (e.g., "max_length")
    # to camelCase (e.g., "maxLength") format, which is commonly used in JSON Schema.
    # The transformation happens in place, modifying the original hash.
    #
    # @param hash [Hash] The hash containing snake_case keys
    # @return [Hash] The same hash with keys transformed to camelCase
    def camelize(hash)
      hash.transform_keys! { |key| snake_to_camel(key.to_s).to_sym }
    end

    # Converts a snake_case string to camelCase
    #
    # Takes a string in snake_case format (e.g., "max_length") and converts it
    # to camelCase format (e.g., "maxLength") by capitalizing each word after
    # the first one and removing underscores.
    #
    # @param str [String] The snake_case string to convert
    # @return [String] The converted camelCase string
    def snake_to_camel(str)
      str.split("_").inject { |memo, word| memo + word.capitalize }
    end
  end
end

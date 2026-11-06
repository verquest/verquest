# frozen_string_literal: true

module Verquest
  module Conditions
    # Reads what a documented oneOf variant decides about its properties
    #
    # Only the variant's top-level `required`, `properties` and
    # `additionalProperties` are read, so an answer of true holds for every
    # payload the variant accepts. Rules use it to tell whether `given` is
    # already decided by a variant (see {Condition#to_one_of_schema}).
    #
    # @example
    #   variant = {"required" => ["a"], "properties" => {"a" => {}}, "additionalProperties" => false}
    #   VariantShape.required?(variant, "a") # => true
    #   VariantShape.forbidden?(variant, "b") # => true
    module VariantShape
      module_function

      # Checks whether every payload of the variant has the property
      #
      # @param variant [Hash] The variant schema
      # @param property_name [String] The property name
      # @return [Boolean]
      def required?(variant, property_name)
        variant.fetch("required", []).include?(property_name)
      end

      # Checks whether no payload of the variant has the property
      #
      # @param variant [Hash] The variant schema
      # @param property_name [String] The property name
      # @return [Boolean]
      def forbidden?(variant, property_name)
        properties = variant.fetch("properties", {})
        properties[property_name] == false || (!properties.key?(property_name) && variant["additionalProperties"] == false)
      end
    end
  end
end

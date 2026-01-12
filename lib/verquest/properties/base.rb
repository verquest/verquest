# frozen_string_literal: true

module Verquest
  module Properties
    # Base class for all property types
    #
    # This abstract class defines the interface for all property types
    # in the Verquest schema system. All property classes should inherit
    # from this base class and implement its required methods.
    #
    # @abstract Subclass and override {#to_schema}, {#mapping} to implement
    class Base
      include HelperMethods::RequiredProperties

      # @!attribute [rw] name
      #   @return [String] The name of the property
      # @!attribute [rw] required
      #   @return [Boolean] Whether this property is required
      # @!attribute [rw] map
      #   @return [String, nil] The mapping path for this property
      attr_accessor :name, :required, :map

      # Adds a child property to this property
      # @abstract
      # @param property [Verquest::Properties::Base] The property to add
      # @raise [NoMethodError] This is an abstract method that must be overridden
      def add(property)
        raise NoMethodError
      end

      # Generates JSON schema for this property
      # @abstract
      # @return [Hash] The schema definition for this property
      # @raise [NoMethodError] This is an abstract method that must be overridden
      def to_schema
        raise NoMethodError
      end

      # Generates validation schema for this property, defaults to the same as `to_schema`
      # @param version [String, nil] The version to generate validation schema for
      # @return [Hash] The validation schema for this property
      def to_validation_schema(version: nil)
        to_schema
      end

      # Creates mapping for this property
      # @abstract
      # @param key_prefix [Array<String>] Prefix for the source key
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param mapping [Hash] The mapping hash to be updated
      # @param version [String, nil] The version to create mapping for
      # @return [void]
      # @raise [NoMethodError] This is an abstract method that must be overridden
      def mapping(key_prefix:, value_prefix:, mapping:, version:)
        raise NoMethodError
      end

      private

      # @!attribute [r] nullable
      #   @return [Boolean] Whether this property can be null
      attr_reader :nullable

      # Determines the mapping target key based on mapping configuration
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param collection [Boolean] Whether this is a collection mapping
      # @return [String] The target mapping key
      def mapping_value_key(value_prefix:, collection: false)
        value_key = if map.nil?
          (value_prefix + [name]).join("/")
        elsif map == "/"
          ""
        elsif map.start_with?("/")
          map.gsub(%r{^/}, "")
        else
          (value_prefix + map.split("/")).join("/")
        end

        if collection
          value_key + "[]"
        else
          value_key
        end
      end

      # Determines the mapping target value prefix based on mapping configuration
      # @param value_prefix [Array<String>] Prefix for the target value
      # @param collection [Boolean] Whether this is a collection mapping
      # @return [Array<String>] The target mapping value prefix
      def mapping_value_prefix(value_prefix:, collection: false)
        value_prefix = if map.nil?
          value_prefix + [name]
        elsif map == "/"
          []
        elsif map.start_with?("/")
          map.gsub(%r{^/}, "").split("/")
        else
          value_prefix + map.split("/")
        end

        if collection && value_prefix.any?
          last = value_prefix.pop
          value_prefix.push((last.to_s + "[]").to_sym)
        end

        value_prefix
      end
    end
  end
end

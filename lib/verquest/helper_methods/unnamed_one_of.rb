# frozen_string_literal: true

module Verquest
  module HelperMethods
    # Checks that an unnamed oneOf is the only property in its scope
    #
    # An unnamed oneOf stands for the whole scope: the version, or a
    # collection item. Its variants have nowhere to go next to other
    # properties, so that is rejected when the properties are declared.
    module UnnamedOneOf
      # The error raised for an unnamed oneOf next to other properties
      MESSAGE = "An unnamed one_of must be the only property in its scope. Give it a name: to declare it next to other properties"

      private

      # @param property [Verquest::Properties::Base] The property being added
      # @return [void]
      # @raise [ArgumentError] If an unnamed oneOf would share the scope with other properties
      def check_unnamed_one_of(property)
        # A property with the same name replaces the existing one, as in an inheriting version
        others = properties.values.reject { |other| other.name.to_s == property.name.to_s }
        return if others.empty?
        return unless unnamed_one_of?(property) || others.any? { |other| unnamed_one_of?(other) }

        raise ArgumentError, MESSAGE
      end

      # @param property [Verquest::Properties::Base] The property
      # @return [Boolean] True for a oneOf without a name
      def unnamed_one_of?(property)
        property.is_a?(Properties::OneOf) && property.name.nil?
      end
    end
  end
end

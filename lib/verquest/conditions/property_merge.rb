# frozen_string_literal: true

module Verquest
  module Conditions
    # Merges the properties declared in condition branches into one hash
    #
    # A name may be declared in several branches only if every declaration
    # produces the same schema and has the same `map:`. That keeps the flat
    # mapping unambiguous.
    module PropertyMerge
      module_function

      # Merges property hashes in order, keeping the first declaration of each name
      #
      # @param property_hashes [Array<Hash<String, Verquest::Properties::Base>>] The properties to merge
      # @return [Hash<String, Verquest::Properties::Base>] The merged properties
      # @raise [ArgumentError] If a name is declared differently
      def call(property_hashes)
        property_hashes.reduce({}) do |merged, properties|
          merged.merge(properties) { |name, declared, other| pick(name, declared, other) }
        end
      end

      # Returns the first declaration if both declarations are the same
      #
      # @param name [String] The property name
      # @param declared [Verquest::Properties::Base] The declaration merged so far
      # @param other [Verquest::Properties::Base] Another declaration of the same name
      # @return [Verquest::Properties::Base] The first declaration
      # @raise [ArgumentError] If the declarations differ
      def pick(name, declared, other)
        return declared if same?(declared, other)

        raise ArgumentError, "Property '#{name}' is declared differently in several condition branches"
      end

      # Checks whether two declarations produce the same schema and mapping
      #
      # @param declared [Verquest::Properties::Base] The first declaration
      # @param other [Verquest::Properties::Base] The second declaration
      # @return [Boolean] true if class, `map:` and schema are the same
      def same?(declared, other)
        declared.instance_of?(other.class) && declared.map == other.map && declared.to_schema == other.to_schema
      end
    end
  end
end

# frozen_string_literal: true

module Verquest
  module Query
    # Rejects query and path versions with shapes their location can't express
    #
    # Query parameters are scalars, arrays of scalars, or one level of objects
    # sent as `deepObject` (`filter[status]=open`). Path parameters are required
    # scalars. Anything else, and oneOf properties, raise when the version is
    # prepared, as does `case_insensitive` on a property without string enum
    # values, or with values equal case-insensitively.
    class DefinitionCheck
      # @param version [Verquest::Version] The query or path version to check
      # @param query_options [Hash{Array<String> => Hash}] The version's query options, by path
      def initialize(version, query_options: {})
        @version = version
        @query_options = query_options
      end

      # @return [void]
      # @raise [Verquest::DefinitionError] If the version uses an unsupported shape
      def call
        raise DefinitionError, "Version '#{version.name}' has a root-level one_of, which #{version.location} parameters can't express" if version.combination?

        version.all_properties.each_value do |property|
          reject([property.name], "a one_of") if property.is_a?(Properties::OneOf)
        end

        version.validation_schema.fetch("properties", {}).each do |name, property_schema|
          (version.location == :path) ? check_path(property_schema, name) : check(property_schema, [name], nested: false)
        end

        query_options.each { |path, options| check_case_insensitive(path) if options[:case_insensitive] }
      end

      private

      attr_reader :version, :query_options

      # Rejects path parameters that aren't required scalars
      #
      # @return [void]
      def check_path(property_schema, name)
        types = variants(property_schema).flat_map { |variant| Array(variant["type"]) }

        reject([name], "an array") if types.include?("array")
        reject([name], "an object") if types.include?("object")
        return if version.validation_schema.fetch("required", []).include?(name)

        raise DefinitionError, "Property '#{name}' in version '#{version.name}' is optional, but path parameters are always required"
      end

      # Checks the objects and arrays of a property schema and its variants
      #
      # @return [void]
      def check(property_schema, path, nested:)
        variants(property_schema).each do |variant|
          types = Array(variant["type"])

          check_object(variant, path, nested:) if types.include?("object")
          check_items(variant["items"], path) if types.include?("array") && variant.key?("items")
        end
      end

      # Rejects a nested object, then checks the object's properties
      #
      # @return [void]
      def check_object(object_schema, path, nested:)
        reject(path, "a nested object") if nested

        object_schema.fetch("properties", {}).each do |name, child_schema|
          check(child_schema, path + [name], nested: true)
        end
      end

      # Rejects array items that are objects or arrays
      #
      # @return [void]
      def check_items(items_schema, path)
        item_types = variants(items_schema).flat_map { |variant| Array(variant["type"]) }

        reject(path, "an array of objects or arrays") if item_types.intersect?(%w[object array])
      end

      # Rejects case_insensitive on a property without string enum values (for an array, its items'),
      # or with two values equal case-insensitively
      #
      # @return [void]
      # @raise [Verquest::DefinitionError] If the property can't match case-insensitively
      def check_case_insensitive(path)
        label = "Property '#{path.join("/")}' in version '#{version.name}' is case_insensitive"
        strings = enum_strings(property_schemas(path))
        raise DefinitionError, "#{label}, which needs string enum values" if strings.empty?

        first, second = strings.group_by { |value| value.downcase(:fold) }.values.find { |same| same.size > 1 }
        raise DefinitionError, "#{label}, but its enum values #{first.inspect} and #{second.inspect} differ only by case" if first
      end

      # @return [Array<Hash>] The schemas at the path, through anyOf and oneOf variants, with an array's items in place of the array
      def property_schemas(path)
        schemas = path.reduce([version.validation_schema]) do |current, name|
          current.flat_map { |schema| variants(schema) }.filter_map { |schema| schema.dig("properties", name) }
        end

        schemas.flat_map { |schema| variants(schema) }.map do |schema|
          (Array(schema["type"]).include?("array") && schema.key?("items")) ? schema["items"] : schema
        end
      end

      # @return [Array<String>] The distinct string enum values of the schemas and their variants
      def enum_strings(schemas)
        schemas.flat_map { |schema| variants(schema) }.flat_map { |schema| Array(schema["enum"]) }.grep(::String).uniq
      end

      # @return [Array<Hash>] The schema and its anyOf and oneOf variants
      def variants(schema)
        [schema, *schema.values_at("anyOf", "oneOf").compact.flatten]
      end

      # @raise [Verquest::DefinitionError] Always
      def reject(path, shape)
        raise DefinitionError, "Property '#{path.join("/")}' in version '#{version.name}' is #{shape}, which #{version.location} parameters can't express"
      end
    end
  end
end

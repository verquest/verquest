# frozen_string_literal: true

require "test_helper"

module Verquest
  class VersionTest < Minitest::Test
    def test_version_inheritance
      base_version = Version.new(name: "1")
      base_version.add(Properties::Field.new(name: :field1, type: :string))
      base_version.add(Properties::Field.new(name: :field2, type: :integer))
      base_version.add(Properties::Field.new(name: :field3, type: :number))

      derived_version = Version.new(name: "2")
      derived_version.copy_from(base_version, exclude_properties: %i[field3])

      assert_equal 2, derived_version.properties.size
      assert derived_version.has?(:field1)
      assert derived_version.has?(:field2)
    end

    def test_multiple_nested_one_of_supported
      version = Version.new(name: "2025-06")
      version.add(Properties::Field.new(name: :field1, type: :string))

      # Add first nested oneOf
      one_of_1 = Properties::OneOf.new(name: "payment", discriminator: "method")
      version.add(one_of_1)

      # Add second nested oneOf
      one_of_2 = Properties::OneOf.new(name: "shipping", discriminator: "type")
      version.add(one_of_2)

      # Should not raise - multiple named oneOf is now supported
      version.prepare

      assert_predicate version, :has_multiple_nested_one_of?
      assert version.mapping.key?("_oneOfs")
      assert_equal 2, version.mapping["_oneOfs"].size
    end
  end
end

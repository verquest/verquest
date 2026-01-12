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

    def test_remove_property
      version = Version.new(name: "2025-06")
      version.add(Properties::Field.new(name: :field1, type: :string))
      version.add(Properties::Field.new(name: :field2, type: :integer))

      removed = version.remove(:field1)

      assert_equal "field1", removed.name
      refute version.has?(:field1)
      assert version.has?(:field2)
    end

    def test_remove_nonexistent_property_raises_error
      version = Version.new(name: "2025-06")
      version.add(Properties::Field.new(name: :field1, type: :string))

      error = assert_raises(PropertyNotFoundError) do
        version.remove(:nonexistent)
      end

      assert_match(/Property .* is not defined/, error.message)
    end

    def test_copy_from_non_version_raises_error
      version = Version.new(name: "2025-06")

      error = assert_raises(ArgumentError) do
        version.copy_from("not a version")
      end

      assert_equal "Expected a Verquest::Version instance", error.message
    end

    def test_mapping_for_nonexistent_property_raises_error
      version = Version.new(name: "2025-06")
      version.add(Properties::Field.new(name: :field1, type: :string))
      version.prepare

      error = assert_raises(PropertyNotFoundError) do
        version.mapping_for(:nonexistent)
      end

      assert_match(/Property .* is not defined/, error.message)
    end

    def test_mapping_for_existing_property
      version = Version.new(name: "2025-06")
      version.add(Properties::Field.new(name: :field1, type: :string, map: "renamed_field"))
      version.prepare

      mapping = version.mapping_for(:field1)

      assert_equal({"field1" => "renamed_field"}, mapping)
    end

    def test_has_nested_one_of
      version = Version.new(name: "2025-06")
      version.add(Properties::Field.new(name: :field1, type: :string))
      version.add(Properties::OneOf.new(name: "payment", discriminator: "method"))

      assert_predicate version, :has_nested_one_of?
      refute_predicate version, :has_multiple_nested_one_of?
    end

    def test_no_nested_one_of
      version = Version.new(name: "2025-06")
      version.add(Properties::Field.new(name: :field1, type: :string))

      refute_predicate version, :has_nested_one_of?
      refute_predicate version, :has_multiple_nested_one_of?
    end
  end
end

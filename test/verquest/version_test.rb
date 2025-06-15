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
  end
end

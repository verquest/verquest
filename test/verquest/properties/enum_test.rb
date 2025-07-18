# frozen_string_literal: true

require "test_helper"

class Verquest::Properties::EnumTest < Minitest::Test
  def test_to_schema
    enum = Verquest::Properties::Enum.new(
      name: :user_type,
      values: %w[member admin]
    )

    expected_schema = {
      "user_type" => {
        "enum" => %w[member admin]
      }
    }

    assert_equal expected_schema, enum.to_schema
  end

  def test_to_validation_schema
    enum = Verquest::Properties::Enum.new(
      name: :user_type,
      values: %w[member admin]
    )

    expected_schema = {
      "user_type" => {
        "enum" => %w[member admin]
      }
    }

    assert_equal expected_schema, enum.to_validation_schema(version: "2025-06")
  end

  def test_mapping_without_map
    enum = Verquest::Properties::Enum.new(
      name: :user_type,
      values: %w[member admin]
    )

    mapping = {}
    enum.mapping(key_prefix: [], value_prefix: [], mapping: mapping)

    expected_mapping = {
      "user_type" => "user_type"
    }

    assert_equal expected_mapping, mapping
  end

  def test_mapping_with_map
    enum = Verquest::Properties::Enum.new(
      name: :user_type,
      values: %w[member admin],
      map: "another/user_type"
    )

    mapping = {}
    enum.mapping(key_prefix: [], value_prefix: [], mapping: mapping)

    expected_mapping = {
      "user_type" => "another/user_type"
    }

    assert_equal expected_mapping, mapping
  end
end

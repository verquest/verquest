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

  def test_nullable_schema_contains_null_value
    enum = Verquest::Properties::Enum.new(name: :user_type, values: %w[member admin], nullable: true)
    expected_schema = {"user_type" => {"enum" => ["member", "admin", nil]}}

    assert_equal expected_schema, enum.to_schema
    assert_equal expected_schema, enum.to_validation_schema(version: "2025-06")
  end

  def test_nullable_enum_does_not_mutate_supplied_values
    values = %w[member admin]
    Verquest::Properties::Enum.new(name: :user_type, values: values, nullable: true)

    assert_equal %w[member admin], values
  end

  def test_nullable_enum_accepts_frozen_values
    enum = Verquest::Properties::Enum.new(name: :user_type, values: %w[member admin].freeze, nullable: true)

    assert_equal ["member", "admin", nil], enum.to_schema["user_type"]["enum"]
  end

  def test_nullable_enum_does_not_duplicate_explicit_null
    enum = Verquest::Properties::Enum.new(name: :user_type, values: ["member", nil], nullable: true)

    assert_equal ["member", nil], enum.to_schema["user_type"]["enum"]
  end

  def test_nullable_enum_preserves_explicit_null_string
    enum = Verquest::Properties::Enum.new(name: :user_type, values: %w[member null], nullable: true)

    assert_equal ["member", "null", nil], enum.to_schema["user_type"]["enum"]
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

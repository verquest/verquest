# frozen_string_literal: true

require "test_helper"

class Verquest::Properties::EnumTest < Minitest::Test
  include Verquest::ConfigurationTestHelper

  def schema(values, **options) = Verquest::Properties::Enum.new(name: :e, values:, **options).to_schema["e"]

  def test_to_schema
    enum = Verquest::Properties::Enum.new(
      name: :user_type,
      values: %w[member admin]
    )

    expected_schema = {
      "user_type" => {
        "type" => "string",
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
        "type" => "string",
        "enum" => %w[member admin]
      }
    }

    assert_equal expected_schema, enum.to_validation_schema(version: "2025-06")
  end

  def test_nullable_schema_contains_null_value
    enum = Verquest::Properties::Enum.new(name: :user_type, values: %w[member admin], nullable: true)
    expected_schema = {"user_type" => {"type" => %w[string null], "enum" => ["member", "admin", nil]}}

    assert_equal expected_schema, enum.to_schema
    assert_equal expected_schema, enum.to_validation_schema(version: "2025-06")
  end

  def test_type_is_inferred_from_the_values
    assert_equal({"type" => "integer", "enum" => [1, 2]}, schema([1, 2]))
    assert_equal({"type" => "number", "enum" => [1, 2.5]}, schema([1, 2.5]))
    assert_equal({"type" => "boolean", "enum" => [true, false]}, schema([true, false]))
  end

  def test_mixed_values_infer_a_type_union
    assert_equal({"type" => %w[integer string], "enum" => [7, "never"]}, schema([7, "never"]))
  end

  def test_explicit_type_is_kept
    assert_equal({"enum" => [1, 2], "type" => "number"}, schema([1, 2], type: "number"))
  end

  # Values without a JSON type would make an inferred type reject them, so no type is written
  def test_no_type_for_values_without_a_json_type
    assert_equal({"enum" => %i[a b]}, schema(%i[a b]))
  end

  # OpenAPI 3.0 has no type arrays: nullable is a keyword, and mixed values get no type
  def test_openapi30
    with_configuration(json_schema_version: :openapi30) do
      assert_equal({"type" => "string", "nullable" => true, "enum" => ["a", "b", nil]}, schema(%w[a b], nullable: true))
      assert_equal({"enum" => [7, "never"]}, schema([7, "never"]))
    end
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

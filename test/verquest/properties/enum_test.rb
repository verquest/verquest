# frozen_string_literal: true

require "test_helper"
require "bigdecimal"

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
    cases = {
      [1, 2] => "integer",
      [1, 2.5] => "number",
      [BigDecimal("1.5"), 2] => "number",
      [true, false] => "boolean",
      [{"a" => 1}, {"b" => 2}] => "object",
      [7, "never"] => %w[integer string]
    }

    assert_equal cases, cases.to_h { |values, _| [values, schema(values)["type"]] }
  end

  def test_type_is_written_before_the_values
    assert_equal({"type" => "string", "enum" => %w[a b]}, schema(%w[a b]))
  end

  def test_explicit_type
    cases = {
      [[1, 2], "number"] => "number",
      [%w[a b], :string] => "string",
      [%w[a b], %w[string string]] => "string",
      [[1, "b"], %i[integer string]] => %w[integer string]
    }

    assert_equal cases, cases.to_h { |(values, type), _| [[values, type], schema(values, type:)["type"]] }
  end

  def test_nullable_adds_null_to_the_type
    assert_equal({"type" => %w[string null], "enum" => ["a", "b", nil]}, schema(%w[a b], nullable: true))
    assert_equal({"type" => %w[string null], "enum" => ["a", "b", nil]}, schema(%w[a b], type: "string", nullable: true))
    assert_equal({"type" => %w[integer string null], "enum" => [1, "b", nil]}, schema([1, "b"], type: %w[integer string], nullable: true))
  end

  # The enum writes JSON Schema forms; Version converts documents for OpenAPI 3.0
  def test_schema_ignores_the_json_schema_version
    with_configuration(json_schema_version: :openapi30) do
      assert_equal({"type" => %w[string null], "enum" => ["a", "b", nil]}, schema(%w[a b], nullable: true))
    end
  end

  def test_values_without_a_json_type_raise
    cases = {
      %i[a b] => "Enum value :a is not a String, Numeric, boolean or Hash (Symbols never match JSON values, use Strings)",
      [[1], [2]] => "Enum value [1] is not a String, Numeric, boolean or Hash"
    }

    assert_equal cases, cases.to_h { |values, _| [values, assert_raises(ArgumentError) { schema(values) }.message] }
  end

  # JSON has no NaN or Infinity, so they can't be generated
  def test_non_finite_numbers_raise
    cases = {[Float::NAN, 1.0] => "Enum values must be finite numbers", [Float::INFINITY, 1] => "Enum values must be finite numbers"}

    assert_equal cases.values, cases.keys.map { |values| assert_raises(ArgumentError) { schema(values) }.message }
  end

  def test_nil_without_nullable_raises
    error = assert_raises(ArgumentError) { schema(["a", nil]) }

    assert_equal "Values include nil, which needs nullable: true", error.message
  end

  def test_values_must_fit_the_explicit_type
    cases = {
      [[1, 2.5], :integer] => "Enum value 2.5 is not of type integer",
      [%i[a b], :string] => "Enum value :a is not of type string",
      [[true, false], %w[string integer]] => "Enum value true is not of type string or integer"
    }

    assert_equal cases, cases.to_h { |(values, type), _| [[values, type], assert_raises(ArgumentError) { schema(values, type:) }.message] }
  end

  def test_unknown_explicit_type_raises
    cases = {
      :uuid => "Unknown enum type :uuid, use one of string, integer, number, boolean, object",
      [] => "Unknown enum type [], use one of string, integer, number, boolean, object"
    }

    assert_equal cases, cases.to_h { |type, _| [type, assert_raises(ArgumentError) { schema(%w[a b], type:) }.message] }
  end

  def test_values_must_be_unique_as_json
    cases = [[1, 1.0], [1, BigDecimal(1)]]

    assert_equal ["Values must be unique"] * 2, cases.map { |values| assert_raises(ArgumentError) { schema(values) }.message }
  end

  def test_values_must_be_an_array
    cases = {"ab" => "Values must be an Array", nil => "Values must be an Array"}

    assert_equal cases, cases.to_h { |values, _| [values, assert_raises(ArgumentError) { schema(values) }.message] }
  end

  def test_hash_values_must_be_json
    hint = " (Symbols never match JSON values, use Strings)"
    cases = {
      [{a: 1}, {"b" => 2}] => "Enum value #{{a: 1}.inspect} has key :a, which is not a String#{hint}",
      [{1 => 1}, {"b" => 2}] => "Enum value #{{1 => 1}.inspect} has key 1, which is not a String",
      [{"a" => [:x]}, {"b" => 2}] => "Enum value #{{"a" => [:x]}.inspect} contains :x, which is not a JSON value#{hint}",
      [{"a" => Float::NAN}, {"b" => 2}] => "Enum values must be finite numbers"
    }

    assert_equal cases, cases.to_h { |values, _| [values, assert_raises(ArgumentError) { schema(values) }.message] }
  end

  def test_hash_values_are_checked_with_an_explicit_type
    object = Object.new
    cases = {
      [{a: 1}, {"b" => 2}] => "Enum value #{{a: 1}.inspect} has key :a, which is not a String (Symbols never match JSON values, use Strings)",
      [{"a" => object}, {"b" => 2}] => "Enum value #{{"a" => object}.inspect} contains #{object.inspect}, which is not a JSON value"
    }

    assert_equal cases, cases.to_h { |values, _| [values, assert_raises(ArgumentError) { schema(values, type: :object) }.message] }
  end

  def test_hash_values_must_be_unique_as_json
    assert_equal "Values must be unique", assert_raises(ArgumentError) { schema([{"a" => 1}, {"a" => 1.0}]) }.message
  end

  def test_nested_json_hash_values
    values = [{"a" => [1, nil, "x"], "b" => {}}, {"a" => {"c" => true}}]

    assert_equal({"type" => "object", "enum" => values}, schema(values))
  end

  def test_invalid_definitions_raise
    cases = {
      {values: []} => "Values must not be empty",
      {values: %w[a]} => "Use const for a single value",
      {values: %w[a b], map: "/"} => "You can not map enums to the root without a name"
    }

    assert_equal cases, cases.to_h { |options, _| [options, assert_raises(ArgumentError) { Verquest::Properties::Enum.new(name: :e, **options) }.message] }
  end

  # The type of with_options is meant for fields; the enum infers its own
  def test_with_options_type_does_not_reach_enums
    request = Class.new(Verquest::Base) do
      version("2025-06") do
        with_options(type: :string) do
          field :name
          enum :size, values: [1, 2]
        end
      end
    end

    assert_equal({"type" => "integer", "enum" => [1, 2]}, request.to_schema(version: "2025-06")["properties"]["size"])
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

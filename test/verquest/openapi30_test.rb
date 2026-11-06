# frozen_string_literal: true

require "test_helper"

class Verquest::Openapi30Test < Minitest::Test
  def document(schema) = Verquest::Openapi30.document(schema)

  def test_null_in_a_type_array_becomes_nullable
    assert_equal({"type" => "string", "nullable" => true}, document({"type" => %w[string null]}))
  end

  def test_single_type_array_becomes_a_string
    assert_equal({"type" => "string"}, document({"type" => %w[string]}))
  end

  # OpenAPI 3.0 honours nullable only next to type, so each branch carries it (as versponse does)
  def test_type_union_becomes_an_any_of
    expected = {"anyOf" => [{"type" => "integer", "nullable" => true}, {"type" => "string", "nullable" => true}], "enum" => [1, "a", nil]}

    assert_equal expected, document({"type" => %w[integer string null], "enum" => [1, "a", nil]})
  end

  def test_type_union_without_null
    assert_equal({"anyOf" => [{"type" => "integer"}, {"type" => "string"}]}, document({"type" => %w[integer string]}))
  end

  def test_type_union_next_to_an_any_of
    schema = {"type" => %w[integer string], "anyOf" => [{"minimum" => 1}, {"minLength" => 1}]}
    expected = {
      "allOf" => [
        {"anyOf" => [{"type" => "integer"}, {"type" => "string"}]},
        {"anyOf" => [{"minimum" => 1}, {"minLength" => 1}]}
      ]
    }

    assert_equal expected, document(schema)
  end

  def test_nullable_ref_is_wrapped_in_all_of
    schema = {"default" => nil, "anyOf" => [{"$ref" => "#/components/schemas/A"}, {"type" => "null"}]}
    expected = {"allOf" => [{"$ref" => "#/components/schemas/A"}], "default" => nil, "nullable" => true}

    assert_equal expected, document(schema)
  end

  # OpenAPI 3.0 needs null listed in an enum next to nullable
  def test_nullable_schema_is_merged_with_null_in_its_enum
    schema = {"default" => "user", "anyOf" => [{"enum" => ["user"]}, {"type" => "null"}]}

    assert_equal({"enum" => ["user", nil], "default" => "user", "nullable" => true}, document(schema))
  end

  def test_nullable_any_of_with_several_variants
    schema = {"anyOf" => [{"type" => "string"}, {"type" => "integer"}, {"type" => "null"}]}

    assert_equal({"anyOf" => [{"type" => "string"}, {"type" => "integer"}], "nullable" => true}, document(schema))
  end

  # A boolean alternative has nothing to merge into
  def test_nullable_boolean_alternative_stays_in_an_any_of
    assert_equal({"anyOf" => [true], "nullable" => true}, document({"anyOf" => [true, {"type" => "null"}]}))
  end

  def test_nested_schemas_are_converted
    schema = {
      "type" => "object",
      "properties" => {
        "tags" => {"type" => %w[array null], "items" => {"type" => %w[string null]}},
        "meta" => {"type" => "object", "additionalProperties" => {"type" => %w[integer null]}},
        "pet" => {"oneOf" => [{"type" => %w[object null]}]}
      }
    }
    expected = {
      "type" => "object",
      "properties" => {
        "tags" => {"type" => "array", "nullable" => true, "items" => {"type" => "string", "nullable" => true}},
        "meta" => {"type" => "object", "additionalProperties" => {"type" => "integer", "nullable" => true}},
        "pet" => {"oneOf" => [{"type" => "object", "nullable" => true}]}
      }
    }

    assert_equal expected, document(schema)
  end

  # Property names are never read as keywords, and data such as enum values is never converted
  def test_only_schema_positions_are_converted
    schema = {
      "type" => "object",
      "properties" => {"type" => {"type" => %w[string null]}, "anyOf" => {"type" => "string"}},
      "default" => {"type" => %w[string null]}
    }
    expected = {
      "type" => "object",
      "properties" => {"type" => {"type" => "string", "nullable" => true}, "anyOf" => {"type" => "string"}},
      "default" => {"type" => %w[string null]}
    }

    assert_equal expected, document(schema)
  end

  # A lone null has no OpenAPI 3.0 form, and booleans are not schemas to convert
  def test_schemas_without_a_3_0_form_are_kept
    cases = [
      {"type" => "object", "additionalProperties" => false},
      {"type" => "null"},
      {"type" => ["null"]},
      {"anyOf" => [{"type" => "null"}]}
    ]

    assert_equal cases, cases.map { |schema| document(schema) }
  end

  def test_input_is_not_modified
    schema = {"type" => %w[string null], "properties" => {"a" => {"type" => %w[integer null]}.freeze}.freeze}.freeze

    document(schema)

    assert_equal({"type" => %w[string null], "properties" => {"a" => {"type" => %w[integer null]}}}, schema)
  end
end

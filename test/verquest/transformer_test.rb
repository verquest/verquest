# frozen_string_literal: true

require "test_helper"

class Verquest::TransformerTest < Minitest::Test
  def test_array_of_objects_transformation
    mapping = {
      "users[]/firstName" => "users[]/first_name",
      "users[]/lastName" => "users[]/last_name"
    }
    input = {
      "users" => [
        {"firstName" => "Alice", "lastName" => "Smith"},
        {"firstName" => "Bob", "lastName" => "Jones"}
      ]
    }
    expected = {
      "users" => [
        {"first_name" => "Alice", "last_name" => "Smith"},
        {"first_name" => "Bob", "last_name" => "Jones"}
      ]
    }
    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_array_of_objects_with_missing_property
    mapping = {
      "users[]/firstName" => "users[]/first_name",
      "users[]/lastName" => "users[]/last_name"
    }
    input = {
      "users" => [
        {"firstName" => "Alice"},
        {"firstName" => "Bob", "lastName" => "Jones"}
      ]
    }
    expected = {
      "users" => [
        {"first_name" => "Alice"},
        {"first_name" => "Bob", "last_name" => "Jones"}
      ]
    }
    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_schema_based_variant_inference
    mapping = {
      "_variant_schemas" => {
        "with_id" => {
          "type" => "object",
          "required" => %w[id name],
          "properties" => {
            "id" => {"type" => "string"},
            "name" => {"type" => "string"}
          },
          "additionalProperties" => false
        },
        "without_id" => {
          "type" => "object",
          "required" => %w[name description],
          "properties" => {
            "name" => {"type" => "string"},
            "description" => {"type" => "string"}
          },
          "additionalProperties" => false
        }
      },
      "with_id" => {"id" => "id", "name" => "name"},
      "without_id" => {"name" => "name", "description" => "description"}
    }

    transformer = Verquest::Transformer.new(mapping: mapping)

    # Test with_id variant
    result = transformer.call({"id" => "123", "name" => "Test"})

    assert_equal({"id" => "123", "name" => "Test"}, result)

    # Test without_id variant
    result = transformer.call({"name" => "Test", "description" => "A test item"})

    assert_equal({"name" => "Test", "description" => "A test item"}, result)
  end

  def test_schema_based_variant_inference_nested
    mapping = {
      "_variant_schemas" => {
        "with_id" => {
          "type" => "object",
          "required" => %w[id name],
          "properties" => {
            "id" => {"type" => "string"},
            "name" => {"type" => "string"}
          },
          "additionalProperties" => false
        },
        "without_id" => {
          "type" => "object",
          "required" => %w[name description],
          "properties" => {
            "name" => {"type" => "string"},
            "description" => {"type" => "string"}
          },
          "additionalProperties" => false
        }
      },
      "_variant_path" => "item",
      "with_id" => {"item/id" => "item/id", "item/name" => "item/name"},
      "without_id" => {"item/name" => "item/name", "item/description" => "item/description"}
    }

    transformer = Verquest::Transformer.new(mapping: mapping)

    # Test with_id variant nested
    result = transformer.call({"item" => {"id" => "123", "name" => "Test"}})

    assert_equal({"item" => {"id" => "123", "name" => "Test"}}, result)

    # Test without_id variant nested
    result = transformer.call({"item" => {"name" => "Test", "description" => "A test item"}})

    assert_equal({"item" => {"name" => "Test", "description" => "A test item"}}, result)
  end

  def test_schema_based_variant_inference_no_match
    mapping = {
      "_variant_schemas" => {
        "with_id" => {
          "type" => "object",
          "required" => %w[id name],
          "properties" => {
            "id" => {"type" => "string"},
            "name" => {"type" => "string"}
          },
          "additionalProperties" => false
        }
      },
      "with_id" => {"id" => "id", "name" => "name"}
    }

    transformer = Verquest::Transformer.new(mapping: mapping)

    # Input that doesn't match any schema (missing required 'id')
    error = assert_raises(Verquest::MappingError) do
      transformer.call({"name" => "Test"})
    end

    assert_match(/No matching schema found/, error.message)
  end

  def test_schema_based_variant_inference_ambiguous
    mapping = {
      "_variant_schemas" => {
        "schema_a" => {"type" => "object", "properties" => {"name" => {"type" => "string"}}, "additionalProperties" => true},
        "schema_b" => {"type" => "object", "properties" => {"name" => {"type" => "string"}}, "additionalProperties" => true}
      },
      "schema_a" => {"name" => "name"},
      "schema_b" => {"name" => "name"}
    }

    transformer = Verquest::Transformer.new(mapping: mapping)

    # Input that matches both schemas (ambiguous)
    error = assert_raises(Verquest::MappingError) { transformer.call({"name" => "Test"}) }

    assert_match(/Ambiguous oneOf match.*schema_a.*schema_b|Ambiguous oneOf match.*schema_b.*schema_a/, error.message)
  end
end

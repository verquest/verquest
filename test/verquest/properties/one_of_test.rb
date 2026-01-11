# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/dog_component"
require_relative "../../support/examples/cat_component"

class Verquest::Properties::OneOfTest < Minitest::Test
  def test_to_schema_without_name
    one_of_property = Verquest::Properties::OneOf.new(
      name: nil,
      discriminator: "type",
      required: false
    )

    one_of_property.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of_property.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    expected_schema = {
      "oneOf" => [
        {"$ref" => "#/components/schemas/DogComponent"},
        {"$ref" => "#/components/schemas/CatComponent"}
      ],
      "discriminator" => {
        "propertyName" => "type",
        "mapping" => {
          "dog" => "#/components/schemas/DogComponent",
          "cat" => "#/components/schemas/CatComponent"
        }
      }
    }

    assert_equal expected_schema, one_of_property.to_schema
  end

  def test_to_schema_with_name
    one_of_property = Verquest::Properties::OneOf.new(
      name: "animal",
      discriminator: "type",
      required: false
    )

    one_of_property.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of_property.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    expected_schema = {
      "animal" => {
        "oneOf" => [
          {"$ref" => "#/components/schemas/DogComponent"},
          {"$ref" => "#/components/schemas/CatComponent"}
        ],
        "discriminator" => {
          "propertyName" => "type",
          "mapping" => {
            "dog" => "#/components/schemas/DogComponent",
            "cat" => "#/components/schemas/CatComponent"
          }
        }
      }
    }

    assert_equal expected_schema, one_of_property.to_schema
  end

  def test_to_validation_schema_without_name
    one_of_property = Verquest::Properties::OneOf.new(
      name: nil,
      discriminator: "type",
      required: false
    )

    one_of_property.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of_property.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    expected_schema = {
      "oneOf" => [
        {"type" => "object", "required" => %w[type name], "properties" => {"type" => {"const" => "dog"}, "name" => {"type" => "string"}, "bark" => {"type" => "boolean"}}, "additionalProperties" => false},
        {"type" => "object", "required" => %w[type name], "properties" => {"type" => {"const" => "cat"}, "name" => {"type" => "string"}, "meow" => {"type" => "boolean"}}, "additionalProperties" => false}
      ],
      "discriminator" => {
        "propertyName" => "type",
        "mapping" => {
          "dog" => {"type" => "object", "required" => %w[type name], "properties" => {"type" => {"const" => "dog"}, "name" => {"type" => "string"}, "bark" => {"type" => "boolean"}}, "additionalProperties" => false},
          "cat" => {"type" => "object", "required" => %w[type name], "properties" => {"type" => {"const" => "cat"}, "name" => {"type" => "string"}, "meow" => {"type" => "boolean"}}, "additionalProperties" => false}
        }
      }
    }

    assert_equal expected_schema, one_of_property.to_validation_schema(version: "2025-06")
  end

  def test_to_validation_schema_with_name
    one_of_property = Verquest::Properties::OneOf.new(
      name: "animal",
      discriminator: "type",
      required: false
    )

    one_of_property.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of_property.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    expected_schema = {
      "animal" => {
        "oneOf" => [
          {"type" => "object", "required" => %w[type name], "properties" => {"type" => {"const" => "dog"}, "name" => {"type" => "string"}, "bark" => {"type" => "boolean"}}, "additionalProperties" => false},
          {"type" => "object", "required" => %w[type name], "properties" => {"type" => {"const" => "cat"}, "name" => {"type" => "string"}, "meow" => {"type" => "boolean"}}, "additionalProperties" => false}
        ],
        "discriminator" => {
          "propertyName" => "type",
          "mapping" => {
            "dog" => {"type" => "object", "required" => %w[type name], "properties" => {"type" => {"const" => "dog"}, "name" => {"type" => "string"}, "bark" => {"type" => "boolean"}}, "additionalProperties" => false},
            "cat" => {"type" => "object", "required" => %w[type name], "properties" => {"type" => {"const" => "cat"}, "name" => {"type" => "string"}, "meow" => {"type" => "boolean"}}, "additionalProperties" => false}
          }
        }
      }
    }

    assert_equal expected_schema, one_of_property.to_validation_schema(version: "2025-06")
  end

  def test_mapping_without_name
    one_of = Verquest::Properties::OneOf.new(
      name: nil,
      discriminator: "type",
      required: false
    )

    one_of.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    mapping = {}
    one_of.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: "2025-06")

    expected_mapping = {
      "dog" => {"type" => "type", "name" => "name", "bark" => "bark"},
      "cat" => {"type" => "type", "name" => "name", "meow" => "meow"}
    }

    assert_equal expected_mapping, mapping
  end

  def test_mapping_with_name
    one_of = Verquest::Properties::OneOf.new(
      name: "pet",
      discriminator: "type",
      required: false
    )

    one_of.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    mapping = {}
    one_of.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: "2025-06")

    expected_mapping = {
      "_discriminator" => "pet/type",
      "dog" => {"pet/type" => "pet/type", "pet/name" => "pet/name", "pet/bark" => "pet/bark"},
      "cat" => {"pet/type" => "pet/type", "pet/name" => "pet/name", "pet/meow" => "pet/meow"}
    }

    assert_equal expected_mapping, mapping
  end

  def test_mapping_with_key_prefix
    one_of = Verquest::Properties::OneOf.new(
      name: "pet",
      discriminator: "type",
      required: false
    )

    one_of.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    mapping = {}
    one_of.mapping(key_prefix: ["request"], value_prefix: [], mapping: mapping, version: "2025-06")

    expected_mapping = {
      "_discriminator" => "request/pet/type",
      "dog" => {"request/pet/type" => "pet/type", "request/pet/name" => "pet/name", "request/pet/bark" => "pet/bark"},
      "cat" => {"request/pet/type" => "pet/type", "request/pet/name" => "pet/name", "request/pet/meow" => "pet/meow"}
    }

    assert_equal expected_mapping, mapping
  end

  def test_to_schema_without_discriminator
    one_of_property = Verquest::Properties::OneOf.new(
      name: "value",
      required: false
    )

    one_of_property.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of_property.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    expected_schema = {
      "value" => {
        "oneOf" => [
          {"$ref" => "#/components/schemas/DogComponent"},
          {"$ref" => "#/components/schemas/CatComponent"}
        ]
      }
    }

    assert_equal expected_schema, one_of_property.to_schema
  end

  def test_to_validation_schema_without_discriminator
    one_of_property = Verquest::Properties::OneOf.new(
      name: "value",
      required: false
    )

    one_of_property.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of_property.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    expected_schema = {
      "value" => {
        "oneOf" => [
          {"type" => "object", "required" => %w[type name], "properties" => {"type" => {"const" => "dog"}, "name" => {"type" => "string"}, "bark" => {"type" => "boolean"}}, "additionalProperties" => false},
          {"type" => "object", "required" => %w[type name], "properties" => {"type" => {"const" => "cat"}, "name" => {"type" => "string"}, "meow" => {"type" => "boolean"}}, "additionalProperties" => false}
        ]
      }
    }

    assert_equal expected_schema, one_of_property.to_validation_schema(version: "2025-06")
  end

  def test_mapping_without_discriminator_includes_variant_schemas
    one_of = Verquest::Properties::OneOf.new(name: "value", required: false)
    one_of.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    mapping = {}
    one_of.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: "2025-06")

    # Should include variant schemas for inference with correct path
    assert_equal "value", mapping["_variant_path"]
    assert_equal %w[cat dog], mapping["_variant_schemas"].keys.sort
  end

  def test_mapping_without_discriminator_variant_mappings
    one_of = Verquest::Properties::OneOf.new(name: "value", required: false)
    one_of.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    mapping = {}
    one_of.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: "2025-06")

    # Should include correct mappings for each variant
    assert_equal({"value/type" => "value/type", "value/name" => "value/name", "value/bark" => "value/bark"}, mapping["dog"])
    assert_equal({"value/type" => "value/type", "value/name" => "value/name", "value/meow" => "value/meow"}, mapping["cat"])
  end

  def test_mapping_without_discriminator_root_level
    one_of = Verquest::Properties::OneOf.new(name: nil, required: false)
    one_of.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    mapping = {}
    one_of.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: "2025-06")

    # Should include variant schemas for inference, but no path for root level
    assert mapping.key?("_variant_schemas") && !mapping.key?("_variant_path")
    assert_equal({"type" => "type", "name" => "name", "bark" => "bark"}, mapping["dog"])
    assert_equal({"type" => "type", "name" => "name", "meow" => "meow"}, mapping["cat"])
  end

  def test_variant_schemas
    one_of = Verquest::Properties::OneOf.new(name: "value", required: false)
    one_of.add(Verquest::Properties::Reference.new(name: "dog", from: DogComponent))
    one_of.add(Verquest::Properties::Reference.new(name: "cat", from: CatComponent))

    schemas = one_of.variant_schemas(version: "2025-06")

    assert_equal %w[cat dog], schemas.keys.sort
    assert schemas.values.all? { |s| s["type"] == "object" }
  end

  def test_discriminator_accessor
    one_of = Verquest::Properties::OneOf.new(
      name: "pet",
      discriminator: "type",
      required: false
    )

    assert_equal "type", one_of.discriminator

    one_of_without = Verquest::Properties::OneOf.new(
      name: "value",
      required: false
    )

    assert_nil one_of_without.discriminator
  end
end

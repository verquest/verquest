# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/pet_request"

# Tests for root-level oneOf with discriminator
class Verquest::RootLevelOneOfTest < Minitest::Test
  def test_schema
    schema = PetRequest.to_schema(version: "2025-06")

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

    assert_equal expected_schema, schema
  end

  def test_validation_schema
    assert PetRequest.valid_schema?(version: "2025-06")

    validation_schema = PetRequest.to_validation_schema(version: "2025-06")

    # Variants live in definitions so OpenAPI validators can select one through the discriminator
    expected_schema = {
      "definitions" => {
        "dog" => {"type" => "object", "required" => %w[type name], "properties" => {"type" => {"const" => "dog"}, "name" => {"type" => "string"}, "bark" => {"type" => "boolean"}}, "additionalProperties" => false},
        "cat" => {"type" => "object", "required" => %w[type name], "properties" => {"type" => {"const" => "cat"}, "name" => {"type" => "string"}, "meow" => {"type" => "boolean"}}, "additionalProperties" => false}
      },
      "oneOf" => [{"$ref" => "#/definitions/dog"}, {"$ref" => "#/definitions/cat"}],
      "discriminator" => {"propertyName" => "type", "mapping" => {"dog" => "#/definitions/dog", "cat" => "#/definitions/cat"}}
    }

    assert_match %r{\Ahttps://verquest\.local/one_of/\h{16}\z}, validation_schema["$id"]
    assert_equal expected_schema, validation_schema.except("$id", "id")
  end

  def test_process_dog
    params = {
      "type" => "dog",
      "name" => "Rex",
      "bark" => true
    }
    Verquest.configuration.validation_error_handling = :result

    result = PetRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal({"type" => "dog", "name" => "Rex", "bark" => true}, result.value)
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_cat
    params = {
      "type" => "cat",
      "name" => "Whiskers",
      "meow" => true
    }
    Verquest.configuration.validation_error_handling = :result

    result = PetRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal({"type" => "cat", "name" => "Whiskers", "meow" => true}, result.value)
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_invalid_discriminator
    params = {
      "type" => "bird",
      "name" => "Tweety"
    }
    Verquest.configuration.validation_error_handling = :result

    result = PetRequest.process(params, version: "2025-06", validate: true)

    refute_predicate result, :success?
    # JSONSchemer validates each schema in oneOf and reports const validation errors
    # when the discriminator value doesn't match any of the defined schemas
    assert_equal "const", result.errors.first[:type]
    assert_equal "/type", result.errors.first[:pointer]
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_mapping
    mapping = PetRequest.mapping(version: "2025-06")

    expected_mapping = {
      "dog" => {"type" => "type", "name" => "name", "bark" => "bark"},
      "cat" => {"type" => "type", "name" => "name", "meow" => "meow"}
    }

    assert_equal expected_mapping, mapping
  end

  def test_external_mapping
    external_mapping = PetRequest.external_mapping(version: "2025-06")

    expected_mapping = {
      "dog" => {"type" => "type", "name" => "name", "bark" => "bark"},
      "cat" => {"type" => "type", "name" => "name", "meow" => "meow"}
    }

    assert_equal expected_mapping, external_mapping
  end
end

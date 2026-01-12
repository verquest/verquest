# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/dog_component"
require_relative "../../support/examples/cat_component"

# Tests for collection with oneOf and discriminator
class Verquest::CollectionWithDiscriminatorOneOfTest < Minitest::Test
  class PetsRequest < Verquest::Base
    version "2025-06" do
      field :owner_name, type: :string, required: true

      collection :pets, required: true do
        one_of discriminator: :type do
          reference :dog, from: DogComponent
          reference :cat, from: CatComponent
        end
      end
    end
  end

  def test_schema_with_discriminator_in_collection
    schema = PetsRequest.to_schema(version: "2025-06")

    expected_items_schema = {
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

    assert_equal "object", schema["type"]
    assert_equal "array", schema["properties"]["pets"]["type"]
    assert_equal expected_items_schema, schema["properties"]["pets"]["items"]
  end

  def test_validation_schema_pets_has_one_of
    validation_schema = PetsRequest.to_validation_schema(version: "2025-06")
    items_schema = validation_schema["properties"]["pets"]["items"]

    assert items_schema.key?("oneOf")
    assert_equal 2, items_schema["oneOf"].size
  end

  def test_validation_schema_pets_omits_discriminator
    # Validation schema omits discriminator (OpenAPI extension, not used by JSON Schema validators)
    validation_schema = PetsRequest.to_validation_schema(version: "2025-06")
    items_schema = validation_schema["properties"]["pets"]["items"]

    refute items_schema.key?("discriminator")
  end

  def test_mapping_with_discriminator_in_collection
    mapping = PetsRequest.mapping(version: "2025-06")

    # Discriminator-based oneOf in collection has _discriminator for per-item resolution
    assert mapping.key?("_discriminator")
    assert mapping.key?("dog")
    assert mapping.key?("cat")
  end

  def test_process_mixed_pets_in_collection
    params = {
      "owner_name" => "John Doe",
      "pets" => [
        {"type" => "dog", "name" => "Rex", "bark" => true},
        {"type" => "cat", "name" => "Whiskers", "meow" => true},
        {"type" => "dog", "name" => "Buddy"}
      ]
    }
    Verquest.configuration.validation_error_handling = :result

    result = PetsRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    expected = {
      "owner_name" => "John Doe",
      "pets" => [
        {"type" => "dog", "name" => "Rex", "bark" => true},
        {"type" => "cat", "name" => "Whiskers", "meow" => true},
        {"type" => "dog", "name" => "Buddy"}
      ]
    }

    assert_equal expected, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_invalid_discriminator_in_collection
    params = {
      "owner_name" => "John Doe",
      "pets" => [
        {"type" => "dog", "name" => "Rex"},
        {"type" => "bird", "name" => "Tweety"}  # Invalid discriminator
      ]
    }
    Verquest.configuration.validation_error_handling = :result

    result = PetsRequest.process(params, version: "2025-06", validate: true)

    refute_predicate result, :success?
    assert_equal "const", result.errors.first[:type]
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_valid_schema
    assert PetsRequest.valid_schema?(version: "2025-06")
  end
end

# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/dog_component"
require_relative "../../support/examples/cat_component"

# Tests for nullable oneOf with discriminator
class Verquest::NullableOneOfWithDiscriminatorTest < Minitest::Test
  class NullablePetRequest < Verquest::Base
    version "2025-06" do
      field :owner_name, type: :string, required: true

      one_of name: :pet, nullable: true, discriminator: "type" do
        reference :dog, from: DogComponent
        reference :cat, from: CatComponent
      end
    end
  end

  def test_schema_includes_three_options
    schema = NullablePetRequest.to_schema(version: "2025-06")

    one_of_array = schema["properties"]["pet"]["oneOf"]

    assert_equal 3, one_of_array.size
  end

  def test_schema_includes_null_type
    schema = NullablePetRequest.to_schema(version: "2025-06")

    one_of_array = schema["properties"]["pet"]["oneOf"]

    assert_includes one_of_array, {"type" => "null"}
  end

  def test_validation_schema_includes_null_type
    validation_schema = NullablePetRequest.to_validation_schema(version: "2025-06")

    pet_schema = validation_schema["properties"]["pet"]
    one_of_array = pet_schema["oneOf"]

    assert_equal 3, one_of_array.size
    assert one_of_array.any? { |s| s["type"] == "null" }
  end

  def test_discriminator_property_name
    schema = NullablePetRequest.to_schema(version: "2025-06")

    discriminator = schema["properties"]["pet"]["discriminator"]

    assert_equal "type", discriminator["propertyName"]
  end

  def test_discriminator_does_not_include_null
    schema = NullablePetRequest.to_schema(version: "2025-06")

    discriminator = schema["properties"]["pet"]["discriminator"]

    assert_equal 2, discriminator["mapping"].size
    refute discriminator["mapping"].key?("null")
  end

  def test_valid_schema
    assert NullablePetRequest.valid_schema?(version: "2025-06")
  end

  def test_process_with_valid_pet
    params = {
      "owner_name" => "John",
      "pet" => {
        "type" => "dog",
        "name" => "Rex",
        "bark" => true
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = NullablePetRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal({"owner_name" => "John", "pet" => {"type" => "dog", "name" => "Rex", "bark" => true}}, result.value)
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_with_null_pet
    params = {
      "owner_name" => "John",
      "pet" => nil
    }
    Verquest.configuration.validation_error_handling = :result

    result = NullablePetRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal({"owner_name" => "John", "pet" => nil}, result.value)
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_mapping_includes_nullable_metadata
    mapping = NullablePetRequest.mapping(version: "2025-06")

    assert mapping["_nullable"]
    assert_equal "pet", mapping["_nullable_path"]
  end
end

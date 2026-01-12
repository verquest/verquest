# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/dog_component"
require_relative "../support/examples/cat_component"

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

# Tests for nullable oneOf without discriminator
class Verquest::NullableOneOfWithoutDiscriminatorTest < Minitest::Test
  class NullableItemRequest < Verquest::Base
    version "2025-06" do
      field :container_id, type: :string, required: true

      one_of name: :item, nullable: true do
        reference :dog, from: DogComponent
        reference :cat, from: CatComponent
      end
    end
  end

  def test_schema_includes_null_type
    schema = NullableItemRequest.to_schema(version: "2025-06")

    item_schema = schema["properties"]["item"]
    one_of_array = item_schema["oneOf"]

    assert_equal 3, one_of_array.size
    assert_includes one_of_array, {"type" => "null"}
  end

  def test_no_discriminator_in_schema
    schema = NullableItemRequest.to_schema(version: "2025-06")

    refute schema["properties"]["item"].key?("discriminator")
  end

  def test_valid_schema
    assert NullableItemRequest.valid_schema?(version: "2025-06")
  end

  def test_process_with_valid_item
    params = {
      "container_id" => "container-1",
      "item" => {
        "type" => "cat",
        "name" => "Whiskers",
        "meow" => true
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = NullableItemRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal({"container_id" => "container-1", "item" => {"type" => "cat", "name" => "Whiskers", "meow" => true}}, result.value)
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_with_null_item
    params = {
      "container_id" => "container-1",
      "item" => nil
    }
    Verquest.configuration.validation_error_handling = :result

    result = NullableItemRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal({"container_id" => "container-1", "item" => nil}, result.value)
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_mapping_includes_nullable_metadata
    mapping = NullableItemRequest.mapping(version: "2025-06")

    assert mapping["_nullable"]
    assert_equal "item", mapping["_nullable_path"]
  end

  def test_mapping_includes_variant_metadata
    mapping = NullableItemRequest.mapping(version: "2025-06")

    assert mapping["_variant_schemas"]
    assert_equal "item", mapping["_variant_path"]
  end
end

# Tests for nullable root-level oneOf
class Verquest::NullableRootLevelOneOfTest < Minitest::Test
  class NullableRootPetRequest < Verquest::Base
    version "2025-06" do
      one_of nullable: true, discriminator: "type" do
        reference :dog, from: DogComponent
        reference :cat, from: CatComponent
      end
    end
  end

  def test_schema_includes_null_type_at_root
    schema = NullableRootPetRequest.to_schema(version: "2025-06")

    one_of_array = schema["oneOf"]

    assert_equal 3, one_of_array.size
    assert_includes one_of_array, {"type" => "null"}
  end

  def test_valid_schema
    assert NullableRootPetRequest.valid_schema?(version: "2025-06")
  end

  def test_process_with_valid_pet
    params = {
      "type" => "dog",
      "name" => "Rex"
    }
    Verquest.configuration.validation_error_handling = :result

    result = NullableRootPetRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal({"type" => "dog", "name" => "Rex"}, result.value)
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_mapping_includes_nullable_without_path
    mapping = NullableRootPetRequest.mapping(version: "2025-06")

    assert mapping["_nullable"]
    refute mapping.key?("_nullable_path")
  end
end

# Tests for non-nullable oneOf (ensure default behavior unchanged)
class Verquest::NonNullableOneOfTest < Minitest::Test
  class NonNullablePetRequest < Verquest::Base
    version "2025-06" do
      field :owner_name, type: :string, required: true

      one_of name: :pet, discriminator: "type" do
        reference :dog, from: DogComponent
        reference :cat, from: CatComponent
      end
    end
  end

  def test_schema_does_not_include_null_type
    schema = NonNullablePetRequest.to_schema(version: "2025-06")

    pet_schema = schema["properties"]["pet"]
    one_of_array = pet_schema["oneOf"]

    assert_equal 2, one_of_array.size
    refute one_of_array.any? { |s| s["type"] == "null" }
  end

  def test_mapping_does_not_include_nullable_metadata
    mapping = NonNullablePetRequest.mapping(version: "2025-06")

    refute mapping.key?("_nullable")
    refute mapping.key?("_nullable_path")
  end
end

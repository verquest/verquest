# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/with_id_component"
require_relative "../support/examples/without_id_component"
require_relative "../support/examples/dog_component"
require_relative "../support/examples/cat_component"

# Tests for oneOf inside a collection without discriminator (array of polymorphic items)
class Verquest::CollectionWithOneOfTest < Minitest::Test
  class ItemsRequest < Verquest::Base
    version "2025-06" do
      field :batch_id, type: :string, required: true

      collection :items, required: true do
        one_of do
          reference :with_id, from: WithIdComponent
          reference :without_id, from: WithoutIdComponent
        end
      end
    end
  end

  def test_schema_with_one_of_in_collection
    schema = ItemsRequest.to_schema(version: "2025-06")

    expected_items_schema = {
      "oneOf" => [
        {"$ref" => "#/components/schemas/WithIdComponent"},
        {"$ref" => "#/components/schemas/WithoutIdComponent"}
      ]
    }

    assert_equal "object", schema["type"]
    assert_equal "array", schema["properties"]["items"]["type"]
    assert_equal expected_items_schema, schema["properties"]["items"]["items"]
  end

  def test_validation_schema_with_one_of_in_collection
    validation_schema = ItemsRequest.to_validation_schema(version: "2025-06")

    # Should have oneOf in items without discriminator
    items_schema = validation_schema["properties"]["items"]["items"]

    assert items_schema.key?("oneOf")
    refute items_schema.key?("discriminator")
    assert_equal 2, items_schema["oneOf"].size
  end

  def test_mapping_with_one_of_in_collection
    mapping = ItemsRequest.mapping(version: "2025-06")

    # Should include variant schemas for inference
    assert mapping.key?("_variant_schemas")
    assert_equal %w[with_id without_id], mapping["_variant_schemas"].keys.sort
  end

  def test_process_mixed_items_in_collection
    params = {
      "batch_id" => "batch-001",
      "items" => [
        {"id" => "item-1", "name" => "First Item", "value" => 100},
        {"name" => "Second Item", "description" => "No ID here"},
        {"id" => "item-2", "name" => "Third Item"}
      ]
    }
    Verquest.configuration.validation_error_handling = :result

    result = ItemsRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    expected = {
      "batch_id" => "batch-001",
      "items" => [
        {"id" => "item-1", "name" => "First Item", "value" => 100},
        {"name" => "Second Item", "description" => "No ID here"},
        {"id" => "item-2", "name" => "Third Item"}
      ]
    }

    assert_equal expected, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_validates_each_item_against_one_of
    params = {
      "batch_id" => "batch-001",
      "items" => [
        {"id" => "item-1", "name" => "Valid with ID"},
        {"unknown_field" => "Invalid item"}  # Doesn't match either schema
      ]
    }
    Verquest.configuration.validation_error_handling = :result

    result = ItemsRequest.process(params, version: "2025-06", validate: true)

    refute_predicate result, :success?
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_valid_schema
    assert ItemsRequest.valid_schema?(version: "2025-06")
  end
end

# Tests for collection with object that includes named oneOf without discriminator
class Verquest::CollectionWithNamedOneOfTest < Minitest::Test
  class EntriesRequest < Verquest::Base
    version "2025-06" do
      field :container_id, type: :string, required: true

      collection :entries, required: true do
        field :entry_id, type: :string, required: true

        one_of name: :content do
          reference :with_id, from: WithIdComponent
          reference :without_id, from: WithoutIdComponent
        end
      end
    end
  end

  def test_schema_type_and_entries_array
    schema = EntriesRequest.to_schema(version: "2025-06")

    assert_equal "object", schema["type"]
    assert_equal "array", schema["properties"]["entries"]["type"]
  end

  def test_schema_entries_item_structure
    schema = EntriesRequest.to_schema(version: "2025-06")
    items_schema = schema["properties"]["entries"]["items"]

    assert_equal "object", items_schema["type"]
    assert_equal({"type" => "string"}, items_schema["properties"]["entry_id"])
  end

  def test_schema_content_one_of
    schema = EntriesRequest.to_schema(version: "2025-06")
    content_schema = schema["properties"]["entries"]["items"]["properties"]["content"]

    expected = {
      "oneOf" => [
        {"$ref" => "#/components/schemas/WithIdComponent"},
        {"$ref" => "#/components/schemas/WithoutIdComponent"}
      ]
    }

    assert_equal expected, content_schema
  end

  def test_validation_schema_entries_item_type
    validation_schema = EntriesRequest.to_validation_schema(version: "2025-06")
    items_schema = validation_schema["properties"]["entries"]["items"]

    assert_equal "object", items_schema["type"]
  end

  def test_validation_schema_content_one_of
    validation_schema = EntriesRequest.to_validation_schema(version: "2025-06")
    content_schema = validation_schema["properties"]["entries"]["items"]["properties"]["content"]

    assert content_schema.key?("oneOf")
    refute content_schema.key?("discriminator")
    assert_equal 2, content_schema["oneOf"].size
  end

  def test_mapping_with_named_one_of_in_collection_object
    mapping = EntriesRequest.mapping(version: "2025-06")

    assert mapping.key?("_variant_schemas")
    assert_equal %w[with_id without_id], mapping["_variant_schemas"].keys.sort
  end

  def test_process_entries_with_named_one_of
    params = {
      "container_id" => "container-001",
      "entries" => [
        {
          "entry_id" => "entry-1",
          "content" => {"id" => "content-1", "name" => "First Content", "value" => 100}
        },
        {
          "entry_id" => "entry-2",
          "content" => {"name" => "Second Content", "description" => "No ID"}
        }
      ]
    }
    Verquest.configuration.validation_error_handling = :result

    result = EntriesRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    expected = {
      "container_id" => "container-001",
      "entries" => [
        {
          "entry_id" => "entry-1",
          "content" => {"id" => "content-1", "name" => "First Content", "value" => 100}
        },
        {
          "entry_id" => "entry-2",
          "content" => {"name" => "Second Content", "description" => "No ID"}
        }
      ]
    }

    assert_equal expected, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_invalid_content_in_entry
    params = {
      "container_id" => "container-001",
      "entries" => [
        {
          "entry_id" => "entry-1",
          "content" => {"unknown_field" => "Invalid content"}
        }
      ]
    }
    Verquest.configuration.validation_error_handling = :result

    result = EntriesRequest.process(params, version: "2025-06", validate: true)

    refute_predicate result, :success?
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_valid_schema
    assert EntriesRequest.valid_schema?(version: "2025-06")
  end
end

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

  def test_validation_schema_pets_has_discriminator
    validation_schema = PetsRequest.to_validation_schema(version: "2025-06")
    items_schema = validation_schema["properties"]["pets"]["items"]

    assert items_schema.key?("discriminator")
    assert_equal "type", items_schema["discriminator"]["propertyName"]
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

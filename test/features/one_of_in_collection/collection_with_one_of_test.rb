# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/with_id_component"
require_relative "../../support/examples/without_id_component"

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

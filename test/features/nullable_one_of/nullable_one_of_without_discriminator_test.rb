# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/dog_component"
require_relative "../../support/examples/cat_component"

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

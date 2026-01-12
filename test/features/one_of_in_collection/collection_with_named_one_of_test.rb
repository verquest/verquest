# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/with_id_component"
require_relative "../../support/examples/without_id_component"

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

# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/with_id_component"
require_relative "../../support/examples/without_id_component"

# Tests for nested oneOf without discriminator
class Verquest::NestedDiscriminatorLessOneOfTest < Minitest::Test
  class ContainerRequest < Verquest::Base
    version "2025-06" do
      field :container_id, type: :string, required: true

      one_of name: :item, required: true do
        reference :with_id, from: WithIdComponent
        reference :without_id, from: WithoutIdComponent
      end
    end
  end

  def test_schema_nested_without_discriminator
    schema = ContainerRequest.to_schema(version: "2025-06")

    expected_item_schema = {
      "oneOf" => [
        {"$ref" => "#/components/schemas/WithIdComponent"},
        {"$ref" => "#/components/schemas/WithoutIdComponent"}
      ]
    }

    assert_equal "object", schema["type"]
    assert_equal expected_item_schema, schema["properties"]["item"]
    refute schema["properties"]["item"].key?("discriminator")
  end

  def test_mapping_nested_includes_variant_schemas_and_path
    mapping = ContainerRequest.mapping(version: "2025-06")

    # Should include variant schemas for inference with correct path
    assert mapping.key?("_variant_schemas"), "Expected _variant_schemas key"
    assert_equal "item", mapping["_variant_path"]
    assert_equal %w[with_id without_id], mapping["_variant_schemas"].keys.sort
  end

  def test_mapping_nested_variant_paths
    mapping = ContainerRequest.mapping(version: "2025-06")

    # Should include mappings for each variant with proper paths
    assert_equal %w[container_id item/id item/name item/value], mapping["with_id"].keys.sort
    assert_equal %w[container_id item/description item/name], mapping["without_id"].keys.sort
  end

  def test_process_nested_with_id_variant
    params = {
      "container_id" => "container-1",
      "item" => {
        "id" => "item-123",
        "name" => "Test Item",
        "value" => 42
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = ContainerRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    expected = {
      "container_id" => "container-1",
      "item" => {
        "id" => "item-123",
        "name" => "Test Item",
        "value" => 42
      }
    }

    assert_equal expected, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_nested_without_id_variant
    params = {
      "container_id" => "container-2",
      "item" => {
        "name" => "Another Item",
        "description" => "Without ID"
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = ContainerRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    expected = {
      "container_id" => "container-2",
      "item" => {
        "name" => "Another Item",
        "description" => "Without ID"
      }
    }

    assert_equal expected, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end
end

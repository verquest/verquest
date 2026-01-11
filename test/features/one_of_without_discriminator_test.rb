# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/with_id_component"
require_relative "../support/examples/without_id_component"

# Tests for root-level oneOf without discriminator - variant is inferred by schema validation
class Verquest::RootLevelDiscriminatorLessOneOfTest < Minitest::Test
  class ItemRequest < Verquest::Base
    version "2025-06" do
      one_of do
        reference :with_id, from: WithIdComponent
        reference :without_id, from: WithoutIdComponent
      end
    end
  end

  def test_schema_without_discriminator
    schema = ItemRequest.to_schema(version: "2025-06")

    expected_schema = {
      "oneOf" => [
        {"$ref" => "#/components/schemas/WithIdComponent"},
        {"$ref" => "#/components/schemas/WithoutIdComponent"}
      ]
    }

    assert_equal expected_schema, schema
  end

  def test_validation_schema_without_discriminator
    validation_schema = ItemRequest.to_validation_schema(version: "2025-06")

    # Should have oneOf array without discriminator block
    assert validation_schema.key?("oneOf")
    refute validation_schema.key?("discriminator")
    assert_equal 2, validation_schema["oneOf"].size
  end

  def test_mapping_includes_variant_schemas
    mapping = ItemRequest.mapping(version: "2025-06")

    # Should include variant schemas for inference and mappings for each variant
    assert mapping.key?("_variant_schemas"), "Expected _variant_schemas key"
    assert_equal %w[with_id without_id], mapping["_variant_schemas"].keys.sort
    assert_equal %w[with_id without_id], (mapping.keys - ["_variant_schemas"]).sort
  end

  def test_process_with_id_variant
    params = {
      "id" => "item-123",
      "name" => "Test Item",
      "value" => 42
    }
    Verquest.configuration.validation_error_handling = :result

    result = ItemRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal({"id" => "item-123", "name" => "Test Item", "value" => 42}, result.value)
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_without_id_variant
    params = {
      "name" => "Test Item",
      "description" => "A test item without ID"
    }
    Verquest.configuration.validation_error_handling = :result

    result = ItemRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal({"name" => "Test Item", "description" => "A test item without ID"}, result.value)
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_no_matching_schema
    params = {
      "unknown_field" => "value"
    }
    Verquest.configuration.validation_error_handling = :result

    result = ItemRequest.process(params, version: "2025-06", validate: true)

    # Validation should fail because input doesn't match any schema
    refute_predicate result, :success?
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_valid_schema
    assert ItemRequest.valid_schema?(version: "2025-06")
  end
end

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

# Tests for ambiguous schema matching
class Verquest::AmbiguousOneOfTest < Minitest::Test
  # Component that overlaps with WithIdComponent
  class OverlappingComponent < Verquest::Base
    version "2025-06" do
      field :id, type: :string, required: true
      field :name, type: :string, required: true
      field :extra, type: :string
    end
  end

  class AmbiguousRequest < Verquest::Base
    version "2025-06" do
      one_of do
        reference :with_id, from: WithIdComponent
        reference :overlapping, from: OverlappingComponent
      end
    end
  end

  def test_ambiguous_match_returns_error
    # Both schemas have required: id, name - input matches both
    params = {
      "id" => "item-123",
      "name" => "Test"
    }
    Verquest.configuration.validation_error_handling = :result

    result = AmbiguousRequest.process(params, version: "2025-06", validate: false)

    refute_predicate result, :success?
    assert_match(/Ambiguous oneOf match/, result.errors.first[:message])
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_ambiguous_match_raises_error
    # Both schemas have required: id, name - input matches both
    params = {
      "id" => "item-123",
      "name" => "Test"
    }

    error = assert_raises(Verquest::MappingError) do
      AmbiguousRequest.process(params, version: "2025-06", validate: false)
    end

    assert_match(/Ambiguous oneOf match/, error.message)
  end

  def test_unambiguous_match_with_extra_field
    # Adding extra field makes it match only OverlappingComponent
    params = {
      "id" => "item-123",
      "name" => "Test",
      "extra" => "additional data"
    }
    Verquest.configuration.validation_error_handling = :result

    # This would fail validation because WithIdComponent has additionalProperties: false
    # but OverlappingComponent allows extra
    result = AmbiguousRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal({"id" => "item-123", "name" => "Test", "extra" => "additional data"}, result.value)
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end
end

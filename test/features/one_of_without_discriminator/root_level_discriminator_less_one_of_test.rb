# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/with_id_component"
require_relative "../../support/examples/without_id_component"

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

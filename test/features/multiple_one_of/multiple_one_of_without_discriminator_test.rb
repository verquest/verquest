# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/with_id_component"
require_relative "../../support/examples/without_id_component"

# Tests for multiple oneOf without discriminators (schema inference)
class Verquest::MultipleOneOfWithoutDiscriminatorTest < Minitest::Test
  class MultiContentRequest < Verquest::Base
    version "2025-06" do
      field :request_id, type: :string, required: true

      one_of name: :primary_content do
        reference :with_id, from: WithIdComponent
        reference :without_id, from: WithoutIdComponent
      end

      one_of name: :secondary_content do
        reference :with_id, from: WithIdComponent
        reference :without_id, from: WithoutIdComponent
      end
    end
  end

  def test_mapping_one_ofs_count
    mapping = MultiContentRequest.mapping(version: "2025-06")

    assert_equal 2, mapping["_oneOfs"].size
  end

  def test_mapping_all_one_ofs_have_variant_schemas
    mapping = MultiContentRequest.mapping(version: "2025-06")

    mapping["_oneOfs"].each do |one_of_mapping|
      assert one_of_mapping.key?("_variant_schemas"), "Expected _variant_schemas for schema inference"
      assert one_of_mapping.key?("_variant_path")
    end
  end

  def test_process_both_with_id
    params = {
      "request_id" => "req-001",
      "primary_content" => {
        "id" => "primary-1",
        "name" => "Primary Content",
        "value" => 100
      },
      "secondary_content" => {
        "id" => "secondary-1",
        "name" => "Secondary Content",
        "value" => 200
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = MultiContentRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal params, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_process_mixed_variants
    params = {
      "request_id" => "req-002",
      "primary_content" => {
        "id" => "primary-1",
        "name" => "Primary Content",
        "value" => 100
      },
      "secondary_content" => {
        "name" => "Secondary Content",
        "description" => "No ID here"
      }
    }
    Verquest.configuration.validation_error_handling = :result

    result = MultiContentRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal params, result.value
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_valid_schema
    assert MultiContentRequest.valid_schema?(version: "2025-06")
  end
end

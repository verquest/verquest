# frozen_string_literal: true

require "test_helper"

# Tests for inline object definitions in oneOf
class Verquest::InlineObjectOneOfTest < Minitest::Test
  class ResultRequest < Verquest::Base
    version "2025-06" do
      field :request_id, type: :string, required: true

      one_of name: :result, discriminator: "status" do
        object :success do
          const :status, value: "success"
          field :data, type: :string, required: true
          field :count, type: :integer
        end

        object :error do
          const :status, value: "error"
          field :message, type: :string, required: true
          field :code, type: :integer
        end
      end
    end
  end

  def test_valid_schema
    assert ResultRequest.valid_schema?(version: "2025-06")
  end

  def test_schema_has_one_of
    schema = ResultRequest.to_schema(version: "2025-06")

    assert schema["properties"]["result"].key?("oneOf")
    assert_equal 2, schema["properties"]["result"]["oneOf"].size
  end

  def test_schema_success_variant_structure
    schema = ResultRequest.to_schema(version: "2025-06")
    one_of_array = schema["properties"]["result"]["oneOf"]
    success_schema = one_of_array.find { |s| s.dig("properties", "status", "const") == "success" }

    assert_equal "object", success_schema["type"]
    assert success_schema["properties"].key?("data")
  end

  def test_schema_error_variant_structure
    schema = ResultRequest.to_schema(version: "2025-06")
    one_of_array = schema["properties"]["result"]["oneOf"]
    error_schema = one_of_array.find { |s| s.dig("properties", "status", "const") == "error" }

    assert_equal "object", error_schema["type"]
    assert error_schema["properties"].key?("message")
  end

  def test_schema_discriminator_is_empty_for_inline_objects
    # Discriminator mapping only includes $ref, so inline objects are skipped
    schema = ResultRequest.to_schema(version: "2025-06")
    discriminator = schema["properties"]["result"]["discriminator"]

    assert_equal "status", discriminator["propertyName"]
    # Mapping is empty because both variants are inline Objects (no $ref)
    assert_empty(discriminator["mapping"])
  end

  def test_validation_schema_has_inline_schemas
    validation_schema = ResultRequest.to_validation_schema(version: "2025-06")
    one_of_array = validation_schema["properties"]["result"]["oneOf"]

    assert_equal 2, one_of_array.size
    assert one_of_array.all? { |s| s["type"] == "object" }
  end

  def test_process_success_result
    params = {
      "request_id" => "req-123",
      "result" => {"status" => "success", "data" => "Hello world", "count" => 42}
    }

    result = ResultRequest.process(params, version: "2025-06")

    assert_equal "req-123", result["request_id"]
    assert_equal({"status" => "success", "data" => "Hello world", "count" => 42}, result["result"])
  end

  def test_process_error_result
    params = {
      "request_id" => "req-456",
      "result" => {"status" => "error", "message" => "Something went wrong", "code" => 500}
    }

    result = ResultRequest.process(params, version: "2025-06")

    assert_equal "req-456", result["request_id"]
    assert_equal({"status" => "error", "message" => "Something went wrong", "code" => 500}, result["result"])
  end

  def test_mapping_includes_both_variants
    mapping = ResultRequest.mapping(version: "2025-06")

    assert mapping.key?("success")
    assert mapping.key?("error")
    assert mapping.key?("_discriminator")
  end

  def test_mapping_success_variant
    mapping = ResultRequest.mapping(version: "2025-06")
    success_mapping = mapping["success"]

    # Properties are mapped directly under result/, not result/success/
    assert success_mapping.key?("result/status")
    assert success_mapping.key?("result/data")
    assert success_mapping.key?("result/count")
  end

  def test_mapping_error_variant
    mapping = ResultRequest.mapping(version: "2025-06")
    error_mapping = mapping["error"]

    # Properties are mapped directly under result/, not result/error/
    assert error_mapping.key?("result/status")
    assert error_mapping.key?("result/message")
    assert error_mapping.key?("result/code")
  end
end

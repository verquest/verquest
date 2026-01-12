# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/dog_component"
require_relative "../support/examples/cat_component"

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

# Tests for mixed inline objects and references in oneOf
class Verquest::MixedOneOfTest < Minitest::Test
  class MixedResultRequest < Verquest::Base
    version "2025-06" do
      field :request_id, type: :string, required: true

      one_of name: :animal, discriminator: "type" do
        # Reference to external component
        reference :dog, from: DogComponent

        # Inline object definition
        object :bird do
          const :type, value: "bird"
          field :name, type: :string, required: true
          field :can_fly, type: :boolean
        end
      end
    end
  end

  def test_valid_schema
    assert MixedResultRequest.valid_schema?(version: "2025-06")
  end

  def test_schema_has_both_ref_and_inline
    schema = MixedResultRequest.to_schema(version: "2025-06")
    one_of_array = schema["properties"]["animal"]["oneOf"]

    # One should be $ref, one should be inline
    ref_schema = one_of_array.find { |s| s.key?("$ref") }
    inline_schema = one_of_array.find { |s| s.key?("type") }

    assert_equal "#/components/schemas/DogComponent", ref_schema["$ref"]
    assert_equal "object", inline_schema["type"]
  end

  def test_discriminator_mapping_only_includes_ref
    schema = MixedResultRequest.to_schema(version: "2025-06")
    discriminator = schema["properties"]["animal"]["discriminator"]

    # Only the Reference (dog) should be in the mapping
    assert_equal 1, discriminator["mapping"].size
    assert discriminator["mapping"].key?("dog")
    refute discriminator["mapping"].key?("bird")
  end

  def test_process_reference_variant
    params = {
      "request_id" => "req-123",
      "animal" => {
        "type" => "dog",
        "name" => "Rex",
        "bark" => true
      }
    }

    result = MixedResultRequest.process(params, version: "2025-06")

    assert_equal "dog", result["animal"]["type"]
    assert_equal "Rex", result["animal"]["name"]
  end

  def test_process_inline_variant
    params = {
      "request_id" => "req-456",
      "animal" => {
        "type" => "bird",
        "name" => "Tweety",
        "can_fly" => true
      }
    }

    result = MixedResultRequest.process(params, version: "2025-06")

    assert_equal "bird", result["animal"]["type"]
    assert_equal "Tweety", result["animal"]["name"]
    assert result["animal"]["can_fly"]
  end

  def test_mapping_includes_both_variants
    mapping = MixedResultRequest.mapping(version: "2025-06")

    assert mapping.key?("dog")
    assert mapping.key?("bird")
  end
end

# Tests for inline objects in oneOf without discriminator
class Verquest::InlineObjectOneOfWithoutDiscriminatorTest < Minitest::Test
  class FlexibleValueRequest < Verquest::Base
    version "2025-06" do
      one_of name: :value do
        object :string_value do
          field :type, type: :string
          field :content, type: :string, required: true
        end

        object :number_value do
          field :type, type: :string
          field :amount, type: :number, required: true
        end
      end
    end
  end

  def test_valid_schema
    assert FlexibleValueRequest.valid_schema?(version: "2025-06")
  end

  def test_schema_has_no_discriminator
    schema = FlexibleValueRequest.to_schema(version: "2025-06")

    refute schema["properties"]["value"].key?("discriminator")
  end

  def test_mapping_includes_variant_schemas
    mapping = FlexibleValueRequest.mapping(version: "2025-06")

    assert mapping.key?("_variant_schemas")
    assert mapping["_variant_schemas"].key?("string_value")
    assert mapping["_variant_schemas"].key?("number_value")
  end

  def test_process_string_value_variant
    params = {
      "value" => {
        "type" => "text",
        "content" => "Hello"
      }
    }

    result = FlexibleValueRequest.process(params, version: "2025-06")

    assert_equal "Hello", result["value"]["content"]
  end

  def test_process_number_value_variant
    params = {
      "value" => {
        "type" => "numeric",
        "amount" => 42.5
      }
    }

    result = FlexibleValueRequest.process(params, version: "2025-06")

    assert_in_delta(42.5, result["value"]["amount"])
  end
end

# Tests for root-level oneOf with inline objects
class Verquest::RootLevelInlineOneOfTest < Minitest::Test
  class RootLevelInlineRequest < Verquest::Base
    version "2025-06" do
      one_of discriminator: "status" do
        object :success do
          const :status, value: "success"
          field :data, type: :string, required: true
        end

        object :error do
          const :status, value: "error"
          field :message, type: :string, required: true
        end
      end
    end
  end

  def test_valid_schema
    assert RootLevelInlineRequest.valid_schema?(version: "2025-06")
  end

  def test_schema_has_inline_objects
    schema = RootLevelInlineRequest.to_schema(version: "2025-06")

    assert schema.key?("oneOf")
    assert_equal 2, schema["oneOf"].size
    assert schema["oneOf"].all? { |s| s["type"] == "object" }
  end

  def test_discriminator_mapping_is_empty
    # No $refs, so discriminator mapping is empty
    schema = RootLevelInlineRequest.to_schema(version: "2025-06")

    assert_equal "status", schema["discriminator"]["propertyName"]
    assert_empty(schema["discriminator"]["mapping"])
  end

  def test_process_success
    params = {"status" => "success", "data" => "Hello"}

    result = RootLevelInlineRequest.process(params, version: "2025-06")

    assert_equal "success", result["status"]
    assert_equal "Hello", result["data"]
  end

  def test_process_error
    params = {"status" => "error", "message" => "Something went wrong"}

    result = RootLevelInlineRequest.process(params, version: "2025-06")

    assert_equal "error", result["status"]
    assert_equal "Something went wrong", result["message"]
  end
end

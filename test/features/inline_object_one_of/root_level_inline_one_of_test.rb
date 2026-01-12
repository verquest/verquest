# frozen_string_literal: true

require "test_helper"

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

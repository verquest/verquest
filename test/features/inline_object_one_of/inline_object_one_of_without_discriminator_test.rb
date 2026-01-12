# frozen_string_literal: true

require "test_helper"

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

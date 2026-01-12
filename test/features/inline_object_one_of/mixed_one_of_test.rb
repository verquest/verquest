# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/dog_component"

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

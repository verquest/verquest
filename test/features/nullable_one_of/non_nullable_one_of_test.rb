# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/dog_component"
require_relative "../../support/examples/cat_component"

# Tests for non-nullable oneOf (ensure default behavior unchanged)
class Verquest::NonNullableOneOfTest < Minitest::Test
  class NonNullablePetRequest < Verquest::Base
    version "2025-06" do
      field :owner_name, type: :string, required: true

      one_of name: :pet, discriminator: "type" do
        reference :dog, from: DogComponent
        reference :cat, from: CatComponent
      end
    end
  end

  def test_schema_does_not_include_null_type
    schema = NonNullablePetRequest.to_schema(version: "2025-06")

    pet_schema = schema["properties"]["pet"]
    one_of_array = pet_schema["oneOf"]

    assert_equal 2, one_of_array.size
    refute one_of_array.any? { |s| s["type"] == "null" }
  end

  def test_mapping_does_not_include_nullable_metadata
    mapping = NonNullablePetRequest.mapping(version: "2025-06")

    refute mapping.key?("_nullable")
    refute mapping.key?("_nullable_path")
  end
end

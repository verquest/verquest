# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/dog_component"
require_relative "../../support/examples/cat_component"

# Tests for nullable root-level oneOf
class Verquest::NullableRootLevelOneOfTest < Minitest::Test
  class NullableRootPetRequest < Verquest::Base
    version "2025-06" do
      one_of nullable: true, discriminator: "type" do
        reference :dog, from: DogComponent
        reference :cat, from: CatComponent
      end
    end
  end

  def test_schema_includes_null_type_at_root
    schema = NullableRootPetRequest.to_schema(version: "2025-06")

    one_of_array = schema["oneOf"]

    assert_equal 3, one_of_array.size
    assert_includes one_of_array, {"type" => "null"}
  end

  def test_valid_schema
    assert NullableRootPetRequest.valid_schema?(version: "2025-06")
  end

  def test_process_with_valid_pet
    params = {
      "type" => "dog",
      "name" => "Rex"
    }
    Verquest.configuration.validation_error_handling = :result

    result = NullableRootPetRequest.process(params, version: "2025-06", validate: true)

    assert_predicate result, :success?
    assert_equal({"type" => "dog", "name" => "Rex"}, result.value)
  ensure
    Verquest.configuration.validation_error_handling = :raise
  end

  def test_mapping_includes_nullable_without_path
    mapping = NullableRootPetRequest.mapping(version: "2025-06")

    assert mapping["_nullable"]
    refute mapping.key?("_nullable_path")
  end
end

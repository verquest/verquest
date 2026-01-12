# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/with_id_component"

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

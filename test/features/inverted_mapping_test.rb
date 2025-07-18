# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/referenced_request"

class Verquest::NullableTest < Minitest::Test
  def test_external_to_internal_mapping
    expected_mapping = {
      "simple_field" => "simple/field",
      "nested/nested_field_1" => "nested/field_1",
      "nested/nested_field_2" => "nested/field_2"
    }

    mapping = ReferencedRequest.mapping(version: "2025-06")

    assert_equal expected_mapping, mapping
  end

  def test_internal_to_external_mapping
    expected_mapping = {
      "simple/field" => "simple_field",
      "nested/field_1" => "nested/nested_field_1",
      "nested/field_2" => "nested/nested_field_2"
    }

    external_mapping = ReferencedRequest.external_mapping(version: "2025-06")

    assert_equal expected_mapping, external_mapping
  end
end

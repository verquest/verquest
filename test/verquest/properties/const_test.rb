# frozen_string_literal: true

require "test_helper"

class Verquest::Properties::ConstTest < Minitest::Test
  def test_to_schema
    const = Verquest::Properties::Const.new(
      name: :test_const,
      value: "value",
      required: true
    )

    expected_schema = {
      "test_const" => {
        "const" => "value"
      }
    }

    assert_equal expected_schema, const.to_schema
  end

  def test_to_validation_schema
    const = Verquest::Properties::Const.new(
      name: :test_const,
      value: "value",
      required: true
    )

    expected_schema = {
      "test_const" => {
        "const" => "value"
      }
    }

    assert_equal expected_schema, const.to_validation_schema(version: "2025-06")
  end

  def test_mapping_without_map
    const = Verquest::Properties::Const.new(
      name: :test_const,
      value: "value",
      required: true
    )

    mapping = {}
    const.mapping(key_prefix: [], value_prefix: [], mapping: mapping)

    expected_mapping = {
      "test_const" => "test_const"
    }

    assert_equal expected_mapping, mapping
  end

  def test_mapping_with_map
    const = Verquest::Properties::Const.new(
      name: :test_const,
      value: "value",
      map: "another_const",
      required: true
    )

    mapping = {}
    const.mapping(key_prefix: [], value_prefix: [], mapping: mapping)

    expected_mapping = {
      "test_const" => "another_const"
    }

    assert_equal expected_mapping, mapping
  end
end

# frozen_string_literal: true

require "test_helper"

class Verquest::TransformerTest < Minitest::Test
  def test_array_of_objects_transformation
    mapping = {
      "users[]/firstName" => "users[]/first_name",
      "users[]/lastName" => "users[]/last_name"
    }
    input = {
      "users" => [
        {"firstName" => "Alice", "lastName" => "Smith"},
        {"firstName" => "Bob", "lastName" => "Jones"}
      ]
    }
    expected = {
      "users" => [
        {"first_name" => "Alice", "last_name" => "Smith"},
        {"first_name" => "Bob", "last_name" => "Jones"}
      ]
    }
    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_array_of_objects_with_missing_property
    mapping = {
      "users[]/firstName" => "users[]/first_name",
      "users[]/lastName" => "users[]/last_name"
    }
    input = {
      "users" => [
        {"firstName" => "Alice"},
        {"firstName" => "Bob", "lastName" => "Jones"}
      ]
    }
    expected = {
      "users" => [
        {"first_name" => "Alice"},
        {"first_name" => "Bob", "last_name" => "Jones"}
      ]
    }
    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end
end

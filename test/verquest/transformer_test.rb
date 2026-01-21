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

  def test_schema_based_variant_inference
    mapping = {
      "_variant_schemas" => {
        "with_id" => {
          "type" => "object",
          "required" => %w[id name],
          "properties" => {
            "id" => {"type" => "string"},
            "name" => {"type" => "string"}
          },
          "additionalProperties" => false
        },
        "without_id" => {
          "type" => "object",
          "required" => %w[name description],
          "properties" => {
            "name" => {"type" => "string"},
            "description" => {"type" => "string"}
          },
          "additionalProperties" => false
        }
      },
      "with_id" => {"id" => "id", "name" => "name"},
      "without_id" => {"name" => "name", "description" => "description"}
    }

    transformer = Verquest::Transformer.new(mapping: mapping)

    # Test with_id variant
    result = transformer.call({"id" => "123", "name" => "Test"})

    assert_equal({"id" => "123", "name" => "Test"}, result)

    # Test without_id variant
    result = transformer.call({"name" => "Test", "description" => "A test item"})

    assert_equal({"name" => "Test", "description" => "A test item"}, result)
  end

  def test_schema_based_variant_inference_nested
    mapping = {
      "_variant_schemas" => {
        "with_id" => {
          "type" => "object",
          "required" => %w[id name],
          "properties" => {
            "id" => {"type" => "string"},
            "name" => {"type" => "string"}
          },
          "additionalProperties" => false
        },
        "without_id" => {
          "type" => "object",
          "required" => %w[name description],
          "properties" => {
            "name" => {"type" => "string"},
            "description" => {"type" => "string"}
          },
          "additionalProperties" => false
        }
      },
      "_variant_path" => "item",
      "with_id" => {"item/id" => "item/id", "item/name" => "item/name"},
      "without_id" => {"item/name" => "item/name", "item/description" => "item/description"}
    }

    transformer = Verquest::Transformer.new(mapping: mapping)

    # Test with_id variant nested
    result = transformer.call({"item" => {"id" => "123", "name" => "Test"}})

    assert_equal({"item" => {"id" => "123", "name" => "Test"}}, result)

    # Test without_id variant nested
    result = transformer.call({"item" => {"name" => "Test", "description" => "A test item"}})

    assert_equal({"item" => {"name" => "Test", "description" => "A test item"}}, result)
  end

  def test_schema_based_variant_inference_no_match
    mapping = {
      "_variant_schemas" => {
        "with_id" => {
          "type" => "object",
          "required" => %w[id name],
          "properties" => {
            "id" => {"type" => "string"},
            "name" => {"type" => "string"}
          },
          "additionalProperties" => false
        }
      },
      "with_id" => {"id" => "id", "name" => "name"}
    }

    transformer = Verquest::Transformer.new(mapping: mapping)

    # Input that doesn't match any schema (missing required 'id')
    error = assert_raises(Verquest::MappingError) do
      transformer.call({"name" => "Test"})
    end

    assert_match(/No matching schema found/, error.message)
  end

  def test_schema_based_variant_inference_ambiguous
    mapping = {
      "_variant_schemas" => {
        "schema_a" => {"type" => "object", "properties" => {"name" => {"type" => "string"}}, "additionalProperties" => true},
        "schema_b" => {"type" => "object", "properties" => {"name" => {"type" => "string"}}, "additionalProperties" => true}
      },
      "schema_a" => {"name" => "name"},
      "schema_b" => {"name" => "name"}
    }

    transformer = Verquest::Transformer.new(mapping: mapping)

    # Input that matches both schemas (ambiguous)
    error = assert_raises(Verquest::MappingError) { transformer.call({"name" => "Test"}) }

    assert_match(/Ambiguous oneOf match.*schema_a.*schema_b|Ambiguous oneOf match.*schema_b.*schema_a/, error.message)
  end

  def test_preserves_null_values
    mapping = {
      "firstName" => "first_name",
      "lastName" => "last_name",
      "middleName" => "middle_name"
    }
    input = {
      "firstName" => "Alice",
      "lastName" => nil,
      "middleName" => "Jane"
    }
    expected = {
      "first_name" => "Alice",
      "last_name" => nil,
      "middle_name" => "Jane"
    }
    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_missing_keys_are_not_included
    mapping = {
      "firstName" => "first_name",
      "lastName" => "last_name",
      "middleName" => "middle_name"
    }
    input = {
      "firstName" => "Alice"
      # lastName and middleName are missing (not present in hash)
    }
    expected = {
      "first_name" => "Alice"
    }
    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_preserves_null_values_in_nested_objects
    mapping = {
      "user/firstName" => "user/first_name",
      "user/lastName" => "user/last_name"
    }
    input = {
      "user" => {
        "firstName" => "Alice",
        "lastName" => nil
      }
    }
    expected = {
      "user" => {
        "first_name" => "Alice",
        "last_name" => nil
      }
    }
    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_preserves_null_values_in_arrays
    mapping = {
      "users[]/firstName" => "users[]/first_name",
      "users[]/lastName" => "users[]/last_name"
    }
    input = {
      "users" => [
        {"firstName" => "Alice", "lastName" => nil},
        {"firstName" => "Bob", "lastName" => "Jones"}
      ]
    }
    expected = {
      "users" => [
        {"first_name" => "Alice", "last_name" => nil},
        {"first_name" => "Bob", "last_name" => "Jones"}
      ]
    }
    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_null_object_does_not_expand_to_nested_structure
    # When an entire object is null, the transformer should not create
    # nested structure with null values for required fields
    mapping = {
      "site/id" => "site/id",
      "site/name" => "site/name",
      "resource/id" => "resource/id",
      "assignee/id" => "assignee/id"
    }
    input = {
      "site" => nil,
      "resource" => nil,
      "assignee" => nil
    }

    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal input, result
  end

  def test_null_object_alongside_other_fields
    mapping = {
      "title" => "title",
      "site/id" => "site/id",
      "site/name" => "site/name",
      "resource/id" => "resource/id"
    }
    input = {
      "title" => "My Title",
      "site" => nil,
      "resource" => nil
    }

    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal input, result
  end

  def test_null_objects_with_nullable_one_of
    # When nullable oneOf is null alongside other nullable objects,
    # all null values should be preserved
    mapping = {
      "_nullable" => true,
      "_nullable_path" => "resource",
      "_variant_schemas" => {
        "unit" => {
          "type" => "object",
          "required" => %w[id],
          "properties" => {"id" => {"type" => "string"}},
          "additionalProperties" => false
        }
      },
      "unit" => {
        "title" => "title",
        "site/id" => "site/id",
        "assignee/id" => "assignee/id",
        "resource/unit/id" => "resource/unit/id"
      }
    }
    input = {
      "site" => nil,
      "resource" => nil,
      "assignee" => nil
    }
    expected = {
      "site" => nil,
      "resource" => nil,
      "assignee" => nil
    }

    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_null_one_of_with_mapping
    # When nullable oneOf has a map: option, the null should use the target path
    mapping = {
      "_nullable" => true,
      "_nullable_path" => "resource",
      "_nullable_target_path" => "taskable",
      "_variant_schemas" => {
        "unit" => {
          "type" => "object",
          "required" => %w[id],
          "properties" => {"id" => {"type" => "string"}},
          "additionalProperties" => false
        }
      },
      "unit" => {
        "title" => "title",
        "site/id" => "site/id",
        "assignee/id" => "assigned_to/id",
        "resource/unit/id" => "taskable/unit/id"
      }
    }
    input = {
      "title" => "Test",
      "site" => nil,
      "resource" => nil,
      "assignee" => nil
    }
    expected = {
      "title" => "Test",
      "site" => nil,
      "taskable" => nil,
      "assigned_to" => nil
    }

    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_null_object_with_remapped_path
    # When null object's children are mapped to a different target path,
    # the null should be set at the correct target depth
    mapping = {
      "coupon/id" => "booking/coupon/id",
      "contract_template/id" => "booking/pandadoc_template/id"
    }
    input = {
      "coupon" => nil,
      "contract_template" => nil
    }
    expected = {
      "booking" => {
        "coupon" => nil,
        "pandadoc_template" => nil
      }
    }

    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_null_object_with_remapped_path_mixed_values
    # Test when some objects are null and others have values
    mapping = {
      "coupon/id" => "booking/coupon/id",
      "contract_template/id" => "booking/pandadoc_template/id",
      "customer/name" => "customer/name"
    }
    input = {
      "coupon" => nil,
      "contract_template" => {"id" => "template-123"},
      "customer" => {"name" => "John"}
    }
    expected = {
      "booking" => {
        "coupon" => nil,
        "pandadoc_template" => {"id" => "template-123"}
      },
      "customer" => {"name" => "John"}
    }

    transformer = Verquest::Transformer.new(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end
end

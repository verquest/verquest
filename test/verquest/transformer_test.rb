# frozen_string_literal: true

require "test_helper"

class Verquest::TransformerTest < Minitest::Test
  def test_requires_layout_or_mapping
    assert_equal "Transformer.new needs layout: (or the deprecated mapping:)", assert_raises(ArgumentError) { Verquest::Transformer.new }.message
  end

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
    transformer = build_transformer(mapping: mapping)
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
    transformer = build_transformer(mapping: mapping)
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

    transformer = build_transformer(mapping: mapping)

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

    transformer = build_transformer(mapping: mapping)

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

    transformer = build_transformer(mapping: mapping)

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

    transformer = build_transformer(mapping: mapping)

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
    transformer = build_transformer(mapping: mapping)
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
    transformer = build_transformer(mapping: mapping)
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
    transformer = build_transformer(mapping: mapping)
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
    transformer = build_transformer(mapping: mapping)
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

    transformer = build_transformer(mapping: mapping)
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

    transformer = build_transformer(mapping: mapping)
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

    transformer = build_transformer(mapping: mapping)
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

    transformer = build_transformer(mapping: mapping)
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

    transformer = build_transformer(mapping: mapping)
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

    transformer = build_transformer(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_null_object_with_hoisted_target_path
    # When target path is shallower than source (e.g., "site/id" => "site_id"),
    # null parent should set null at the correct target key
    mapping = {
      "site/id" => "site_id",
      "name" => "name"
    }
    input = {
      "site" => nil,
      "name" => "Test"
    }
    expected = {
      "site_id" => nil,
      "name" => "Test"
    }

    transformer = build_transformer(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_null_object_with_equal_depth_target
    # When target depth equals source depth, should still work
    mapping = {
      "site/id" => "location/id",
      "name" => "name"
    }
    input = {
      "site" => nil,
      "name" => "Test"
    }
    expected = {
      "location" => nil,
      "name" => "Test"
    }

    transformer = build_transformer(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_collection_item_with_null_nested_object
    # transform_item_with_mapping should preserve null parents
    mapping = {
      "_variant_schemas" => {
        "with_site" => {
          "type" => "object",
          "required" => %w[name],
          "properties" => {
            "name" => {"type" => "string"},
            "site" => {
              "oneOf" => [
                {"type" => "object", "properties" => {"id" => {"type" => "string"}}, "required" => ["id"]},
                {"type" => "null"}
              ]
            }
          },
          "additionalProperties" => false
        }
      },
      "with_site" => {
        "items[]/name" => "items[]/name",
        "items[]/site/id" => "items[]/site/id"
      }
    }

    input = {
      "items" => [
        {"name" => "A", "site" => {"id" => "s1"}},
        {"name" => "B", "site" => nil}
      ]
    }
    expected = {
      "items" => [
        {"name" => "A", "site" => {"id" => "s1"}},
        {"name" => "B", "site" => nil}
      ]
    }

    transformer = build_transformer(mapping: mapping)
    result = transformer.call(input)

    assert_equal expected, result
  end

  def test_unknown_discriminator_value_raises_error
    # Unknown discriminator value should raise MappingError, not silently return {}
    mapping = {
      "_discriminator" => "type",
      "dog" => {"type" => "type", "name" => "name", "bark" => "bark"},
      "cat" => {"type" => "type", "name" => "name", "meow" => "meow"}
    }

    transformer = build_transformer(mapping: mapping)

    error = assert_raises(Verquest::MappingError) do
      transformer.call({"type" => "fish", "name" => "Nemo"})
    end

    assert_match(/No matching variant.*fish|Unknown discriminator value.*fish/, error.message)
  end

  def test_schema_inference_with_null_variant_path
    # When variant_path field is present but null, should return base mapping
    # not raise MappingError
    mapping = {
      "_variant_schemas" => {
        "with_id" => {
          "type" => "object",
          "required" => %w[id],
          "properties" => {"id" => {"type" => "string"}},
          "additionalProperties" => false
        }
      },
      "_variant_path" => "resource",
      "with_id" => {
        "title" => "title",
        "resource/id" => "resource/id"
      }
    }

    transformer = build_transformer(mapping: mapping)

    # When resource is null, should not raise
    result = transformer.call({"title" => "Test", "resource" => nil})

    assert_equal({"title" => "Test", "resource" => nil}, result)
  end

  def test_collection_with_one_of_keeps_a_null_collection
    mapping = {
      "_discriminator" => "order/pets[]/type",
      "dog" => {"order/pets[]/type" => "order/animals[]/type", "order/pets[]/bark" => "order/animals[]/bark"},
      "cat" => {"order/pets[]/type" => "order/animals[]/type", "order/pets[]/meow" => "order/animals[]/meow"}
    }
    transformer = build_transformer(mapping: mapping)

    cases = {
      {"order" => {"pets" => nil}} => {"order" => {"animals" => nil}},
      {"order" => nil} => {"order" => nil},
      {"order" => {}} => {},
      {"order" => {"pets" => [{"type" => "cat", "meow" => true}]}} => {"order" => {"animals" => [{"type" => "cat", "meow" => true}]}}
    }

    assert_equal cases, cases.to_h { |input, _| [input, transformer.call(input)] }
  end

  def test_collection_with_one_of_rejects_variant_properties_outside_the_items
    mapping = {
      "_discriminator" => "pets[]/type",
      "dog" => {"pets[]/type" => "dog_type"},
      "cat" => {"pets[]/type" => "cat_type"}
    }

    error = assert_raises(Verquest::MappingError) { build_transformer(mapping: mapping) }

    assert_equal "map: can't move a oneOf variant property out of its collection item (pets[]/type => dog_type)", error.message
  end

  def test_two_one_ofs_in_the_same_collection
    mapping = {
      "id" => "id",
      "_oneOfs" => [
        {
          "_discriminator" => "items[]/pet/type",
          "dog" => {"items[]/pet/type" => "lines[]/animal/type", "items[]/pet/bark" => "lines[]/animal/bark"},
          "cat" => {"items[]/pet/type" => "lines[]/animal/type", "items[]/pet/meow" => "lines[]/animal/meow"}
        },
        {
          "_discriminator" => "items[]/toy/kind",
          "ball" => {"items[]/toy/kind" => "lines[]/toy/kind", "items[]/toy/size" => "lines[]/toy/diameter"},
          "rope" => {"items[]/toy/kind" => "lines[]/toy/kind", "items[]/toy/length" => "lines[]/toy/length"}
        }
      ]
    }
    params = {
      "id" => 1,
      "items" => [
        {"pet" => {"type" => "dog", "bark" => true}, "toy" => {"kind" => "rope", "length" => 2}},
        {"pet" => {"type" => "cat", "meow" => true}, "toy" => {"kind" => "ball", "size" => 3}}
      ]
    }
    expected = {
      "id" => 1,
      "lines" => [
        {"animal" => {"type" => "dog", "bark" => true}, "toy" => {"kind" => "rope", "length" => 2}},
        {"animal" => {"type" => "cat", "meow" => true}, "toy" => {"kind" => "ball", "diameter" => 3}}
      ]
    }

    assert_equal expected, build_transformer(mapping: mapping).call(params)
  end

  def test_transformer_is_frozen
    assert_predicate build_transformer(mapping: {"a" => "b"}), :frozen?
  end

  def test_mapping_constructor_takes_a_root_level_discriminator
    mapping = {"dog" => {"type" => "type", "bark" => "woof"}, "cat" => {"type" => "type", "meow" => "purr"}}

    result = build_transformer(mapping:, discriminator: :type).call({"type" => "dog", "bark" => true})

    assert_equal({"type" => "dog", "woof" => true}, result)
  end

  def test_mapping_constructor_is_deprecated
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true

    assert_output(nil, /transformer_test\.rb:\d+: warning: Verquest::Transformer\.new\(mapping:\) is deprecated and will be removed in 1\.0\.0/) do
      Verquest::Transformer.new(mapping: {"a" => "b"})
    end
  ensure
    Warning[:deprecated] = deprecated
  end

  private

  # Builds a transformer from a mapping without printing the deprecation
  def build_transformer(**options)
    Verquest::DeprecationHelper.without_deprecation_warnings { Verquest::Transformer.new(**options) }
  end
end

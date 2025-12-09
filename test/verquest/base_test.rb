# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/complete_example_request"
require_relative "../support/examples/simple_request"

module Verquest
  class BaseTest < Minitest::Test
    def test_to_schema
      schema = CompleteExampleRequest.to_schema(version: "2025-06")
      expected_schema = {
        "type" => "object",
        "description" => "Example for mapping feature",
        "required" => ["field_root_string_mapped", "field_root_number_mapped_nested", "field_root_boolean_unmapped", "field_root_integer_unmapped"],
        "properties" => {
          "field_root_string_mapped" => {"type" => "string"},
          "field_root_number_mapped_nested" => {"type" => "number"},
          "field_root_boolean_unmapped" => {"type" => "boolean"},
          "field_root_integer_unmapped" => {"type" => "integer"},
          "root_object_unmapped" => {
            "type" => "object",
            "required" => [],
            "properties" => {
              "item_mapped" => {"type" => "string"},
              "item_mapped_nested" => {"type" => "string"},
              "item_unmapped" => {"type" => "string"},
              "item_mapped_to_root" => {"type" => "string"},
              "item_mapped_outside_nested" => {"type" => "string"},
              "object_nested_unmapped" => {
                "type" => "object",
                "required" => [],
                "properties" => {
                  "item_mapped" => {"type" => "string"},
                  "item_mapped_nested" => {"type" => "string"},
                  "item_unmapped" => {"type" => "string"},
                  "item_mapped_to_root" => {"type" => "string"},
                  "item_mapped_outside_nested" => {"type" => "string"},
                  "item_mapped_to_root_object" => {"type" => "string"}
                },
                "additionalProperties" => false
              }
            },
            "additionalProperties" => false
          },
          "root_object_mapped" => {
            "type" => "object",
            "required" => [],
            "properties" => {
              "item_mapped" => {"type" => "string"},
              "item_mapped_nested" => {"type" => "string"},
              "item_unmapped" => {"type" => "string"},
              "object_nested_unmapped" => {
                "type" => "object",
                "required" => [],
                "properties" => {
                  "item_mapped" => {"type" => "string"},
                  "item_mapped_nested" => {"type" => "string"},
                  "item_unmapped" => {"type" => "string"}
                },
                "additionalProperties" => false
              },
              "reference_mapped_to_root" => {"$ref" => "#/components/schemas/ReferencedRequest"},
              "const_mapped_to_root" => {"const" => "const_mapped_to_root"}
            },
            "additionalProperties" => false
          },
          "root_object_mapped_to_root" => {
            "type" => "object",
            "required" => [],
            "properties" => {
              "item_mapped" => {"type" => "string"},
              "item_mapped_nested" => {"type" => "string"},
              "item_unmapped_root_object_mapped_to_root" => {"type" => "string"},
              "collection_unmapped_object_to_root" => {
                "type" => "array",
                "items" => {"$ref" => "#/components/schemas/ReferencedRequest"}
              }
            },
            "additionalProperties" => false
          },
          "collection_unmapped" => {
            "type" => "array",
            "items" => {"$ref" => "#/components/schemas/ReferencedRequest"}
          },
          "collection_mapped" => {
            "type" => "array",
            "items" => {"$ref" => "#/components/schemas/ReferencedRequest"}
          },
          "collection_with_fields" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "required" => [],
              "properties" => {
                "item_mapped" => {"type" => "string"},
                "item_mapped_nested" => {"type" => "string"},
                "item_unmapped" => {"type" => "string"}
              },
              "additionalProperties" => false
            }
          },
          "collection_in_object" => {
            "type" => "object",
            "required" => [],
            "properties" => {
              "collection_unmapped" => {
                "type" => "array",
                "items" => {"$ref" => "#/components/schemas/ReferencedRequest"}
              }
            },
            "additionalProperties" => false
          },
          "array_unmapped" => {"type" => "array", "items" => {"type" => "string", "format" => "uuid"}},
          "array_mapped" => {"type" => "array", "items" => {"type" => "number"}},
          "reference_unmapped" => {"$ref" => "#/components/schemas/ReferencedRequest"},
          "reference_mapped_to_root" => {"$ref" => "#/components/schemas/ReferencedRequest"},
          "reference_unmapped_with_property" => {"$ref" => "#/components/schemas/ReferencedRequest/properties/simple_field"},
          "reference_mapped_with_property" => {"$ref" => "#/components/schemas/ReferencedRequest/properties/simple_field"},
          "const_unmapped" => {"const" => 1},
          "const_mapped" => {"const" => true},
          "enum_unmapped" => {"enum" => %w[one two three]},
          "enum_mapped" => {"enum" => [1, "a", 2, "b", "null"]}
        },
        "additionalProperties" => false
      }

      assert_equal expected_schema, schema
    end

    def test_to_validation_schema
      validation_schema = CompleteExampleRequest.to_validation_schema(version: "2025-06")

      referenced_validation_schema = {
        "type" => "object",
        "description" => "This is an another example for testing purposes.",
        "required" => ["simple_field", "nested"],
        "properties" => {
          "simple_field" => {"type" => "string", "description" => "The simple field"},
          "nested" => {
            "type" => "object",
            "required" => ["nested_field_2"],
            "properties" => {
              "nested_field_1" => {"type" => "string", "description" => "This is a nested field"},
              "nested_field_2" => {"type" => "string", "description" => "This is another nested field"}
            },
            "additionalProperties" => false
          }
        },
        "additionalProperties" => false
      }

      expected_schema = {
        "type" => "object",
        "description" => "Example for mapping feature",
        "required" => ["field_root_string_mapped", "field_root_number_mapped_nested", "field_root_boolean_unmapped", "field_root_integer_unmapped"],
        "properties" => {
          "field_root_string_mapped" => {"type" => "string"},
          "field_root_number_mapped_nested" => {"type" => "number"},
          "field_root_boolean_unmapped" => {"type" => "boolean"},
          "field_root_integer_unmapped" => {"type" => "integer"},
          "root_object_unmapped" => {
            "type" => "object",
            "required" => [],
            "properties" => {
              "item_mapped" => {"type" => "string"},
              "item_mapped_nested" => {"type" => "string"},
              "item_unmapped" => {"type" => "string"},
              "item_mapped_to_root" => {"type" => "string"},
              "item_mapped_outside_nested" => {"type" => "string"},
              "object_nested_unmapped" => {
                "type" => "object",
                "required" => [],
                "properties" => {
                  "item_mapped" => {"type" => "string"},
                  "item_mapped_nested" => {"type" => "string"},
                  "item_unmapped" => {"type" => "string"},
                  "item_mapped_to_root" => {"type" => "string"},
                  "item_mapped_outside_nested" => {"type" => "string"},
                  "item_mapped_to_root_object" => {"type" => "string"}
                },
                "additionalProperties" => false
              }
            },
            "additionalProperties" => false
          },
          "root_object_mapped" => {
            "type" => "object",
            "required" => [],
            "properties" => {
              "item_mapped" => {"type" => "string"},
              "item_mapped_nested" => {"type" => "string"},
              "item_unmapped" => {"type" => "string"},
              "object_nested_unmapped" => {
                "type" => "object",
                "required" => [],
                "properties" => {
                  "item_mapped" => {"type" => "string"},
                  "item_mapped_nested" => {"type" => "string"},
                  "item_unmapped" => {"type" => "string"}
                },
                "additionalProperties" => false
              },
              "reference_mapped_to_root" => referenced_validation_schema,
              "const_mapped_to_root" => {"const" => "const_mapped_to_root"}
            },
            "additionalProperties" => false
          },
          "root_object_mapped_to_root" => {
            "type" => "object",
            "required" => [],
            "properties" => {
              "item_mapped" => {"type" => "string"},
              "item_mapped_nested" => {"type" => "string"},
              "item_unmapped_root_object_mapped_to_root" => {"type" => "string"},
              "collection_unmapped_object_to_root" => {
                "type" => "array",
                "items" => referenced_validation_schema
              }
            },
            "additionalProperties" => false
          },
          "collection_unmapped" => {
            "type" => "array",
            "items" => referenced_validation_schema
          },
          "collection_mapped" => {
            "type" => "array",
            "items" => referenced_validation_schema
          },
          "collection_with_fields" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "required" => [],
              "properties" => {
                "item_mapped" => {"type" => "string"},
                "item_mapped_nested" => {"type" => "string"},
                "item_unmapped" => {"type" => "string"}
              },
              "additionalProperties" => false
            }
          },
          "collection_in_object" => {
            "type" => "object",
            "required" => [],
            "properties" => {
              "collection_unmapped" => {
                "type" => "array",
                "items" => referenced_validation_schema
              }
            },
            "additionalProperties" => false
          },
          "array_unmapped" => {"type" => "array", "items" => {"type" => "string", "format" => "uuid"}},
          "array_mapped" => {"type" => "array", "items" => {"type" => "number"}},
          "reference_unmapped" => referenced_validation_schema,
          "reference_mapped_to_root" => referenced_validation_schema,
          "reference_unmapped_with_property" => {"type" => "string", "description" => "The simple field"},
          "reference_mapped_with_property" => {"type" => "string", "description" => "The simple field"},
          "const_unmapped" => {"const" => 1},
          "const_mapped" => {"const" => true},
          "enum_unmapped" => {"enum" => %w[one two three]},
          "enum_mapped" => {"enum" => [1, "a", 2, "b", "null"]}
        },
        "additionalProperties" => false
      }

      assert_equal expected_schema, validation_schema
    end

    def test_validate_schema
      result = CompleteExampleRequest.valid_schema?(version: "2025-06")

      assert result
    end

    def test_mapping
      mapping = CompleteExampleRequest.mapping(version: "2025-06")

      expected_mapping = {
        "field_root_string_mapped" => "field_root",
        "field_root_number_mapped_nested" => "nested/field_root",
        "field_root_boolean_unmapped" => "field_root_boolean_unmapped",
        "field_root_integer_unmapped" => "field_root_integer_unmapped",
        "root_object_unmapped/item_mapped" => "root_object_unmapped/item_mapped_rename",
        "root_object_unmapped/item_mapped_nested" => "root_object_unmapped/nested/item_mapped",
        "root_object_unmapped/item_unmapped" => "root_object_unmapped/item_unmapped",
        "root_object_unmapped/item_mapped_to_root" => "root_object_item_outside",
        "root_object_unmapped/item_mapped_outside_nested" => "nested/root_object_item_outside",
        "root_object_unmapped/object_nested_unmapped/item_mapped" => "root_object_unmapped/object_nested_unmapped/item_mapped_rename",
        "root_object_unmapped/object_nested_unmapped/item_mapped_nested" => "root_object_unmapped/object_nested_unmapped/nested/item_mapped",
        "root_object_unmapped/object_nested_unmapped/item_unmapped" => "root_object_unmapped/object_nested_unmapped/item_unmapped",
        "root_object_unmapped/object_nested_unmapped/item_mapped_to_root" => "nested_object_item_outside",
        "root_object_unmapped/object_nested_unmapped/item_mapped_outside_nested" => "nested/nested_object_item_outside",
        "root_object_unmapped/object_nested_unmapped/item_mapped_to_root_object" => "root_object_unmapped/nested_object_item_outside",
        "root_object_mapped/item_mapped" => "root/object_mapped/item_mapped_rename",
        "root_object_mapped/item_mapped_nested" => "root/object_mapped/nested/item_mapped",
        "root_object_mapped/item_unmapped" => "root/object_mapped/item_unmapped",
        "root_object_mapped/object_nested_unmapped/item_mapped" => "root/object_mapped/object_nested_mapped/item_mapped_rename",
        "root_object_mapped/object_nested_unmapped/item_mapped_nested" => "root/object_mapped/object_nested_mapped/nested/item_mapped",
        "root_object_mapped/object_nested_unmapped/item_unmapped" => "root/object_mapped/object_nested_mapped/item_unmapped",
        "root_object_mapped/reference_mapped_to_root/simple_field" => "simple/field",
        "root_object_mapped/reference_mapped_to_root/nested/nested_field_1" => "nested/field_1",
        "root_object_mapped/reference_mapped_to_root/nested/nested_field_2" => "nested/field_2",
        "root_object_mapped/const_mapped_to_root" => "const_mapped_to_root",
        "root_object_mapped_to_root/item_mapped" => "item_mapped_rename_root_object_mapped_to_root",
        "root_object_mapped_to_root/item_mapped_nested" => "nested/item_mapped_root_object_mapped_to_root",
        "root_object_mapped_to_root/item_unmapped_root_object_mapped_to_root" => "item_unmapped_root_object_mapped_to_root",
        "root_object_mapped_to_root/collection_unmapped_object_to_root[]/simple_field" => "collection_unmapped_object_to_root[]/simple/field",
        "root_object_mapped_to_root/collection_unmapped_object_to_root[]/nested/nested_field_1" => "collection_unmapped_object_to_root[]/nested/field_1",
        "root_object_mapped_to_root/collection_unmapped_object_to_root[]/nested/nested_field_2" => "collection_unmapped_object_to_root[]/nested/field_2",
        "collection_unmapped[]/simple_field" => "collection_unmapped[]/simple/field",
        "collection_unmapped[]/nested/nested_field_1" => "collection_unmapped[]/nested/field_1",
        "collection_unmapped[]/nested/nested_field_2" => "collection_unmapped[]/nested/field_2",
        "collection_mapped[]/simple_field" => "collection_mapped_somewhere[]/simple/field",
        "collection_mapped[]/nested/nested_field_1" => "collection_mapped_somewhere[]/nested/field_1",
        "collection_mapped[]/nested/nested_field_2" => "collection_mapped_somewhere[]/nested/field_2",
        "collection_with_fields[]/item_mapped" => "collection_with_fields[]/item_mapped_collection",
        "collection_with_fields[]/item_mapped_nested" => "collection_with_fields[]/nested/item_mapped_nested",
        "collection_with_fields[]/item_unmapped" => "collection_with_fields[]/item_unmapped",
        "collection_in_object/collection_unmapped[]/simple_field" => "collection_in_object/collection_unmapped[]/simple/field",
        "collection_in_object/collection_unmapped[]/nested/nested_field_1" => "collection_in_object/collection_unmapped[]/nested/field_1",
        "collection_in_object/collection_unmapped[]/nested/nested_field_2" => "collection_in_object/collection_unmapped[]/nested/field_2",
        "array_unmapped" => "array_unmapped",
        "array_mapped" => "rename_array_mapped",
        "reference_unmapped/simple_field" => "reference_unmapped/simple/field",
        "reference_unmapped/nested/nested_field_1" => "reference_unmapped/nested/field_1",
        "reference_unmapped/nested/nested_field_2" => "reference_unmapped/nested/field_2",
        "reference_mapped_to_root/simple_field" => "referenced/simple/field",
        "reference_mapped_to_root/nested/nested_field_1" => "referenced/nested/field_1",
        "reference_mapped_to_root/nested/nested_field_2" => "referenced/nested/field_2",
        "reference_unmapped_with_property" => "reference_unmapped_with_property",
        "reference_mapped_with_property" => "referenced_with_property",
        "const_unmapped" => "const_unmapped",
        "const_mapped" => "const/mapped",
        "enum_unmapped" => "enum_unmapped",
        "enum_mapped" => "enum/mapped"
      }

      assert_equal expected_mapping, mapping
    end

    def test_map_with_invalid_params_with_result_object
      params = {
        "param" => "This is not a valid parameter"
      }
      expected_errors = [
        {pointer: "/param", type: "schema", message: "object property at `/param` is a disallowed additional property", details: nil},
        {pointer: "", type: "required", message: "object at root is missing required properties: field_root_string_mapped, field_root_number_mapped_nested, field_root_boolean_unmapped, field_root_integer_unmapped", details: {"missing_keys" => ["field_root_string_mapped", "field_root_number_mapped_nested", "field_root_boolean_unmapped", "field_root_integer_unmapped"]}}
      ]

      # with result object
      Verquest.configuration.validation_error_handling = :result
      result = CompleteExampleRequest.process(params, version: "2025-06", validate: true, remove_extra_root_keys: false)

      assert_predicate result, :failure?
      assert_equal expected_errors, result.errors
    ensure
      Verquest.configuration.validation_error_handling = :raise
    end

    def test_map_with_invalid_params_with_exception
      params = {
        "param" => "This is not a valid parameter"
      }
      expected_errors = [
        {pointer: "/param", type: "schema", message: "object property at `/param` is a disallowed additional property", details: nil},
        {pointer: "", type: "required", message: "object at root is missing required properties: field_root_string_mapped, field_root_number_mapped_nested, field_root_boolean_unmapped, field_root_integer_unmapped", details: {"missing_keys" => ["field_root_string_mapped", "field_root_number_mapped_nested", "field_root_boolean_unmapped", "field_root_integer_unmapped"]}}
      ]

      # with raise
      Verquest.configuration.validation_error_handling = :raise
      exception = assert_raises(Verquest::InvalidParamsError) do
        CompleteExampleRequest.process(params, version: "2025-06", validate: true, remove_extra_root_keys: false)
      end
      assert_equal expected_errors, exception.errors
    ensure
      Verquest.configuration.validation_error_handling = :raise
    end

    def test_map_with_valid_params
      params = {
        "field_root_string_mapped" => "field_root_string_mapped",
        "field_root_number_mapped_nested" => 2,
        "field_root_boolean_unmapped" => true,
        "field_root_integer_unmapped" => 1,
        "root_object_unmapped" => {
          "item_mapped" => "item_mapped",
          "item_mapped_nested" => "item_mapped_nested",
          "item_unmapped" => "item_unmapped",
          "item_mapped_to_root" => "item_mapped_to_root",
          "item_mapped_outside_nested" => "item_mapped_outside_nested",
          "object_nested_unmapped" => {
            "item_mapped" => "item_mapped",
            "item_mapped_nested" => "item_mapped_nested",
            "item_unmapped" => "item_unmapped",
            "item_mapped_to_root" => "item_mapped_to_root",
            "item_mapped_outside_nested" => "item_mapped_outside_nested",
            "item_mapped_to_root_object" => "item_mapped_to_root_object"
          }
        },
        "root_object_mapped" => {
          "item_mapped" => "item_mapped",
          "item_mapped_nested" => "item_mapped_nested",
          "item_unmapped" => "item_unmapped",
          "object_nested_unmapped" => {
            "item_mapped" => "item_mapped",
            "item_mapped_nested" => "item_mapped_nested",
            "item_unmapped" => "item_unmapped"
          },
          "reference_mapped_to_root" => {
            "simple_field" => "simple_field",
            "nested" => {
              "nested_field_1" => "nested_field_1",
              "nested_field_2" => "nested_field_2"
            }
          }
        },
        "root_object_mapped_to_root" => {
          "item_mapped" => "item_mapped",
          "item_mapped_nested" => "item_mapped_nested",
          "item_unmapped_root_object_mapped_to_root" => "item_unmapped_root_object_mapped_to_root",
          "collection_unmapped_object_to_root" => [
            {
              "simple_field" => "simple_field",
              "nested" => {
                "nested_field_1" => "nested_field_1",
                "nested_field_2" => "nested_field_2"
              }
            },
            {
              "simple_field" => "simple_field_2",
              "nested" => {
                "nested_field_1" => "nested_field_1_2",
                "nested_field_2" => "nested_field_2_2"
              }
            }
          ]
        },
        "collection_unmapped" => [
          {
            "simple_field" => "simple_field",
            "nested" => {
              "nested_field_1" => "nested_field_1",
              "nested_field_2" => "nested_field_2"
            }
          },
          {
            "simple_field" => "simple_field_2",
            "nested" => {
              "nested_field_1" => "nested_field_1_2",
              "nested_field_2" => "nested_field_2_2"
            }
          }
        ],
        "collection_mapped" => [
          {
            "simple_field" => "simple_field",
            "nested" => {
              "nested_field_1" => "nested_field_1",
              "nested_field_2" => "nested_field_2"
            }
          },
          {
            "simple_field" => "simple_field_2",
            "nested" => {
              "nested_field_1" => "nested_field_1_2",
              "nested_field_2" => "nested_field_2_2"
            }
          }
        ],
        "collection_with_fields" => [
          {
            "item_mapped" => "item_mapped",
            "item_mapped_nested" => "item_mapped_nested",
            "item_unmapped" => "item_unmapped"
          }
        ],
        "collection_in_object" => {
          "collection_unmapped" => [
            {
              "simple_field" => "simple_field",
              "nested" => {
                "nested_field_1" => "nested_field_1",
                "nested_field_2" => "nested_field_2"
              }
            },
            {
              "simple_field" => "simple_field_2",
              "nested" => {
                "nested_field_1" => "nested_field_1_2",
                "nested_field_2" => "nested_field_2_2"
              }
            }
          ]
        },
        "array_unmapped" => %w[4662f352-e1dd-4ab6-9078-ffb12c82e8ad 2a44097e-6bb5-4df9-8091-a925449bd9cf],
        "array_mapped" => [1, 2, 3],
        "reference_unmapped" => {
          "simple_field" => "simple_field",
          "nested" => {
            "nested_field_1" => "nested_field_1",
            "nested_field_2" => "nested_field_2"
          }
        },
        "reference_mapped_to_root" => {
          "simple_field" => "simple_field",
          "nested" => {
            "nested_field_1" => "nested_field_1",
            "nested_field_2" => "nested_field_2"
          }
        },
        "reference_unmapped_with_property" => "reference_unmapped_with_property",
        "reference_mapped_with_property" => "reference_mapped_with_property"
      }

      expected_mapped_params = {
        "field_root" => "field_root_string_mapped",
        "nested" => {
          "field_root" => 2,
          "root_object_item_outside" => "item_mapped_outside_nested",
          "nested_object_item_outside" => "item_mapped_outside_nested",
          "field_1" => "nested_field_1",
          "field_2" => "nested_field_2",
          "item_mapped_root_object_mapped_to_root" => "item_mapped_nested"
        },
        "field_root_boolean_unmapped" => true,
        "field_root_integer_unmapped" => 1,
        "root_object_unmapped" => {
          "item_mapped_rename" => "item_mapped",
          "nested" => {
            "item_mapped" => "item_mapped_nested"
          },
          "item_unmapped" => "item_unmapped",
          "object_nested_unmapped" => {
            "item_mapped_rename" => "item_mapped",
            "nested" => {
              "item_mapped" => "item_mapped_nested"
            },
            "item_unmapped" => "item_unmapped"
          },
          "nested_object_item_outside" => "item_mapped_to_root_object"
        },
        "root_object_item_outside" => "item_mapped_to_root",
        "nested_object_item_outside" => "item_mapped_to_root",
        "root" => {
          "object_mapped" => {
            "item_mapped_rename" => "item_mapped",
            "nested" => {
              "item_mapped" => "item_mapped_nested"
            },
            "item_unmapped" => "item_unmapped",
            "object_nested_mapped" => {
              "item_mapped_rename" => "item_mapped",
              "nested" => {
                "item_mapped" => "item_mapped_nested"
              },
              "item_unmapped" => "item_unmapped"
            }
          }
        },
        "simple" => {"field" => "simple_field"},
        "item_mapped_rename_root_object_mapped_to_root" => "item_mapped",
        "item_unmapped_root_object_mapped_to_root" => "item_unmapped_root_object_mapped_to_root",
        "collection_unmapped_object_to_root" => [
          {
            "simple" => {"field" => "simple_field"},
            "nested" => {"field_1" => "nested_field_1", "field_2" => "nested_field_2"}
          },
          {
            "simple" => {"field" => "simple_field_2"},
            "nested" => {"field_1" => "nested_field_1_2", "field_2" => "nested_field_2_2"}
          }
        ],
        "collection_unmapped" => [
          {
            "simple" => {"field" => "simple_field"},
            "nested" => {"field_1" => "nested_field_1", "field_2" => "nested_field_2"}
          },
          {
            "simple" => {"field" => "simple_field_2"},
            "nested" => {"field_1" => "nested_field_1_2", "field_2" => "nested_field_2_2"}
          }
        ],
        "collection_mapped_somewhere" => [
          {
            "simple" => {"field" => "simple_field"},
            "nested" => {"field_1" => "nested_field_1", "field_2" => "nested_field_2"}
          },
          {
            "simple" => {"field" => "simple_field_2"},
            "nested" => {"field_1" => "nested_field_1_2", "field_2" => "nested_field_2_2"}
          }
        ],
        "collection_with_fields" => [
          {
            "item_mapped_collection" => "item_mapped",
            "nested" => {"item_mapped_nested" => "item_mapped_nested"},
            "item_unmapped" => "item_unmapped"
          }
        ],
        "collection_in_object" => {
          "collection_unmapped" => [
            {
              "simple" => {"field" => "simple_field"},
              "nested" => {"field_1" => "nested_field_1", "field_2" => "nested_field_2"}
            },
            {
              "simple" => {"field" => "simple_field_2"},
              "nested" => {"field_1" => "nested_field_1_2", "field_2" => "nested_field_2_2"}
            }
          ]
        },
        "array_unmapped" => %w[4662f352-e1dd-4ab6-9078-ffb12c82e8ad 2a44097e-6bb5-4df9-8091-a925449bd9cf],
        "rename_array_mapped" => [1, 2, 3],
        "reference_unmapped" => {
          "simple" => {"field" => "simple_field"},
          "nested" => {"field_1" => "nested_field_1", "field_2" => "nested_field_2"}
        },
        "referenced" => {
          "simple" => {"field" => "simple_field"},
          "nested" => {"field_1" => "nested_field_1", "field_2" => "nested_field_2"}
        },
        "reference_unmapped_with_property" => "reference_unmapped_with_property",
        "referenced_with_property" => "reference_mapped_with_property"
      }

      # with result object
      Verquest.configuration.validation_error_handling = :result
      result = CompleteExampleRequest.process(params, version: "2025-06", validate: true)

      assert_predicate result, :success?
      assert_equal expected_mapped_params, result.value

      # with raise
      Verquest.configuration.validation_error_handling = :raise
      mapped_params = CompleteExampleRequest.process(params, version: "2025-06", validate: true)

      assert_equal expected_mapped_params, mapped_params
    ensure
      Verquest.configuration.validation_error_handling = :raise
    end

    def test_version_inheritance
      validation_schema = SimpleRequest.to_validation_schema(version: "2025-08")

      expected_validation_schema = {
        "type" => "object",
        "description" => "This is a simple request for testing purposes.",
        "required" => ["email", "name"], # name is required in this version
        "properties" => {
          "email" => {"type" => "string", "format" => "email"},
          "address" => {
            "type" => "object",
            "required" => ["city"],
            "properties" => {
              "street" => {"type" => "string"},
              "city" => {"type" => "string"},
              "zip_code" => {"type" => "string"}
            },
            "additionalProperties" => true
          },
          "name" => {"type" => "string", "minLength" => 3, "maxLength" => 50}
        }
      }

      assert_equal expected_validation_schema, validation_schema
    end

    def test_version_default_additional_properties
      validation_schema = SimpleRequest.to_validation_schema(version: "2025-06")

      expected_validation_schema = {
        "type" => "object",
        "description" => "This is a simple request for testing purposes.",
        "required" => ["email"], # name is required in this version
        "properties" => {
          "email" => {"type" => "string", "format" => "email"},
          "name" => {"type" => "string"},
          "address" => {
            "type" => "object",
            "required" => ["city"],
            "properties" => {
              "street" => {"type" => "string"},
              "city" => {"type" => "string"},
              "zip_code" => {"type" => "string"}
            },
            "additionalProperties" => true
          }
        },
        "additionalProperties" => true
      }

      assert_equal expected_validation_schema, validation_schema
    end
  end
end

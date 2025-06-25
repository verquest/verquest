# frozen_string_literal: true

require "test_helper"

module Verquest
  module Properties
    class CollectionTest < Minitest::Test
      ::CollectionTestReferenceClass = Class.new(Verquest::Base) do
        version "2025-06" do
          field :reference_field, type: :string, required: true, description: "A test field", map: "renamed_field"
        end
      end

      def test_has_item_with_item
        collection_with_item = Collection.new(
          name: :test_collection,
          item: ::CollectionTestReferenceClass
        )

        assert_predicate collection_with_item, :has_item?
      end

      def test_has_item_without_item
        collection_without_item = Collection.new(
          name: :test_collection
        )

        refute_predicate collection_without_item, :has_item?
      end

      def test_to_schema_with_item
        collection = Collection.new(
          name: :test_collection,
          item: ::CollectionTestReferenceClass,
          description: "A test array of items as references"
        )

        expected_schema = {
          "test_collection" => {
            "type" => "array",
            "items" => {"$ref" => "#/components/schemas/CollectionTestReferenceClass"},
            "description" => "A test array of items as references"
          }
        }

        assert_equal expected_schema, collection.to_schema
      end

      def test_to_schema_with_object
        collection = Collection.new(
          name: :test_collection,
          description: "A test array of items defined as an object"
        )

        sub_field = Field.new(
          name: :sub_field,
          type: :integer,
          required: true
        )
        collection.add(sub_field)

        expected_schema = {
          "test_collection" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "required" => ["sub_field"],
              "properties" => {
                "sub_field" => {"type" => "integer"}
              }
            },
            "description" => "A test array of items defined as an object"
          }
        }

        assert_equal expected_schema, collection.to_schema
      end

      def test_to_validation_schema_with_object
        collection = Collection.new(
          name: :test_collection,
          description: "A test array of items defined as an object"
        )

        sub_field = Field.new(
          name: :sub_field,
          type: :integer,
          required: true
        )
        collection.add(sub_field)

        expected_schema = {
          "test_collection" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "required" => ["sub_field"],
              "properties" => {
                "sub_field" => {"type" => "integer"}
              }
            },
            "description" => "A test array of items defined as an object"
          }
        }

        assert_equal expected_schema, collection.to_schema
      end

      def test_validation_schema_with_item
        collection = Collection.new(
          name: :test_collection,
          item: ::CollectionTestReferenceClass
        )

        expected_schema = {
          "test_collection" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "description" => nil,
              "required" => ["reference_field"],
              "properties" => {
                "reference_field" => {
                  "type" => "string",
                  "description" => "A test field"
                }
              }
            }
          }
        }

        assert_equal expected_schema, collection.to_validation_schema(version: "2025-06")
      end

      def test_mapping_without_properties_from_item
        collection = Collection.new(
          name: :test_collection,
          item: ::CollectionTestReferenceClass
        )

        mapping = {}
        collection.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: "2025-06")

        expected_mapping = {
          "test_collection[].reference_field" => "test_collection[].renamed_field"
        }

        assert_equal expected_mapping, mapping
      end

      def test_mapping_with_properties_from_item
        collection = Collection.new(
          name: :test_collection,
          item: ::CollectionTestReferenceClass,
          map: "renamed_collection"
        )

        mapping = {}
        collection.mapping(key_prefix: [], value_prefix: [], mapping: mapping, version: "2025-06")

        expected_mapping = {
          "test_collection[].reference_field" => "renamed_collection[].renamed_field"
        }

        assert_equal expected_mapping, mapping
      end
    end
  end
end

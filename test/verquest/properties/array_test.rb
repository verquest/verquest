# frozen_string_literal: true

require "test_helper"

module Verquest
  module Properties
    class ArrayTest < Minitest::Test
      def test_to_schema
        array = Array.new(
          name: :test_array,
          type: :string,
          description: "A test array"
        )

        expected_schema = {
          "test_array" => {
            "type" => "array",
            "items" => {"type" => "string"},
            "description" => "A test array"
          }
        }

        assert_equal expected_schema, array.to_schema
      end

      def test_to_validation_schema
        array = Array.new(
          name: :test_array,
          type: :string,
          description: "A test array"
        )

        expected_schema = {
          "test_array" => {
            "type" => "array",
            "items" => {"type" => "string"},
            "description" => "A test array"
          }
        }

        assert_equal expected_schema, array.to_validation_schema
      end

      def test_mapping_root_level
        array = Array.new(
          name: :test_array,
          type: :string,
          map: "mapped/test/array",
          required: true
        )

        mapping = {}
        array.mapping(key_prefix: [], value_prefix: [], mapping: mapping)

        expected_mapping = {
          "test_array" => "mapped/test/array"
        }

        assert_equal expected_mapping, mapping
      end

      def test_mapping_nested
        array = Array.new(
          name: :test_array,
          type: :string,
          map: "array",
          required: true
        )

        mapping = {}
        array.mapping(key_prefix: %w[nested level], value_prefix: %w[nested level], mapping: mapping)

        expected_mapping = {
          "nested/level/test_array" => "nested/level/array"
        }

        assert_equal expected_mapping, mapping
      end

      def test_mapping_with_root_prefix
        array = Array.new(
          name: :test_array,
          type: :string,
          map: "/array",
          required: true
        )

        mapping = {}
        array.mapping(key_prefix: %w[nested level], value_prefix: %w[nested level], mapping: mapping)

        expected_mapping = {
          "nested/level/test_array" => "array"
        }

        assert_equal expected_mapping, mapping
      end

      def test_mapping_without_map
        array = Array.new(
          name: :test_array,
          type: :string,
          required: true
        )

        mapping = {}
        array.mapping(key_prefix: %w[nested level], value_prefix: %w[nested level], mapping: mapping)

        expected_mapping = {
          "nested/level/test_array" => "nested/level/test_array"
        }

        assert_equal expected_mapping, mapping
      end

      def test_custom_field_type
        Verquest.configuration.custom_field_types = {
          custom_type: {
            type: "string",
            schema_options: {format: "custom", pattern: /\Acustom_\w+\z/, min_length: 5, max_length: 20}
          }
        }

        array = Array.new(
          name: :test_array,
          type: :custom_type,
          description: "A test array",
          item_schema_options: {description: "The item"}
        )

        expected_schema = {
          "test_array" => {
            "type" => "array",
            "items" => {
              "type" => "string",
              "format" => "custom",
              "pattern" => /\Acustom_\w+\z/,
              "minLength" => 5,
              "maxLength" => 20,
              "description" => "The item"
            },
            "description" => "A test array"
          }
        }

        assert_equal expected_schema, array.to_schema
      end
    end
  end
end

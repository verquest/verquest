# frozen_string_literal: true

require "test_helper"

module Verquest
  module Query
    class CoercerTest < Minitest::Test
      include ConfigurationTestHelper

      CASES = {
        "integer" => [{"type" => "integer"}, "12", 12],
        "negative integer" => [{"type" => "integer"}, "-3", -3],
        "integer with decimals" => [{"type" => "integer"}, "1.5", "1.5"],
        "integer garbage" => [{"type" => "integer"}, "abc", "abc"],
        "integer already" => [{"type" => "integer"}, 4, 4],
        "number float" => [{"type" => "number"}, "1.5", 1.5],
        "number integer" => [{"type" => "number"}, "-2", -2],
        "number exponent" => [{"type" => "number"}, "1e5", "1e5"],
        "number already" => [{"type" => "number"}, 2.5, 2.5],
        "boolean true" => [{"type" => "boolean"}, "true", true],
        "boolean false" => [{"type" => "boolean"}, "false", false],
        "boolean one" => [{"type" => "boolean"}, "1", "1"],
        "boolean already" => [{"type" => "boolean"}, false, false],
        "string" => [{"type" => "string", "format" => "date"}, "2025", "2025"],
        "string from array" => [{"type" => "string"}, %w[a], %w[a]],
        "nullable string empty" => [{"type" => %w[string null]}, "", ""],
        "null first" => [{"type" => %w[null string]}, "", nil],
        "null first with value" => [{"type" => %w[null integer]}, "5", 5],
        "nullable integer empty" => [{"type" => %w[integer null]}, "", nil],
        "nullable integer nil" => [{"type" => %w[integer null]}, nil, nil],
        "not nullable empty" => [{"type" => "integer"}, "", ""],
        "multiple types" => [{"type" => %w[integer string]}, "7", 7],
        "unknown type" => [{"type" => "file"}, "7", "7"],
        "enum integers" => [{"enum" => [1, 2]}, "2", 2],
        "enum with nil" => [{"enum" => [1, nil]}, "", nil],
        "enum of objects" => [{"enum" => [{"a" => 1}]}, "1", "1"],
        "const boolean" => [{"const" => true}, "true", true],
        "one_of variants" => [{"oneOf" => [{"type" => "integer"}, {"const" => "now"}]}, "5", 5],
        "one_of second variant" => [{"oneOf" => [{"type" => "integer"}, {"const" => "now"}]}, "now", "now"],
        "one_of no variant" => [{"oneOf" => [{"type" => "integer"}, {"type" => "boolean"}]}, "x", "x"],
        "type before variants" => [{"type" => "string", "oneOf" => [{"type" => "integer"}]}, "5", "5"],
        "nullable any_of" => [{"anyOf" => [{"type" => "integer"}, {"type" => "null"}]}, "", nil],
        "no type" => [{}, "1", "1"],
        "array comma" => [{"type" => "array", "items" => {"type" => "integer"}}, "1,2", [1, 2]],
        "array empty" => [{"type" => "array", "items" => {"type" => "string"}}, "", []],
        "array already" => [{"type" => "array", "items" => {"type" => "integer"}}, %w[1 2], [1, 2]],
        "array item garbage" => [{"type" => "array", "items" => {"type" => "integer"}}, "1,x", [1, "x"]],
        "array without items" => [{"type" => "array"}, "a,b", %w[a b]],
        "nullable array empty" => [{"type" => %w[array null]}, "", []],
        "array from hash" => [{"type" => "array"}, {"a" => "1"}, {"a" => "1"}],
        "object from string" => [{"type" => "object"}, "a", "a"]
      }.freeze

      def test_cases
        CASES.each do |label, (value_schema, input, expected)|
          coercer = Coercer.new(schema: object("value" => value_schema), explodes: {%w[value] => false})

          assert_equal({"value" => expected}, coercer.call({"value" => input}), label)
        end
      end

      def test_exploded_string_is_wrapped
        coercer = Coercer.new(schema: object("tags" => {"type" => "array", "items" => {"type" => "integer"}}), explodes: {%w[tags] => true})

        assert_equal({"tags" => [1]}, coercer.call({"tags" => "1"}))
        assert_equal({"tags" => ["1,2"]}, coercer.call({"tags" => "1,2"}))
      end

      def test_case_insensitive_enum
        schema = object(
          "direction" => {"type" => "string", "enum" => %w[ASC DESC]},
          "status" => {"type" => "array", "items" => {"type" => "string", "enum" => %w[open won]}},
          "strict" => {"type" => "string", "enum" => %w[ASC DESC]}
        )
        coercer = Coercer.new(schema:, explodes: {%w[status] => false}, case_insensitive: Set[%w[direction], %w[status]])

        assert_equal({"direction" => "DESC", "status" => %w[open won], "strict" => "desc"},
          coercer.call({"direction" => "desc", "status" => "Open,WON", "strict" => "desc"}))
        assert_equal({"direction" => "ASC"}, coercer.call({"direction" => "ASC"}))
        assert_equal({"direction" => "up"}, coercer.call({"direction" => "up"}))
      end

      def test_case_insensitive_nullable_enum
        schema = object("kind" => {"type" => %w[string null], "enum" => ["unit", "site", nil]})
        coercer = Coercer.new(schema:, explodes: {}, case_insensitive: Set[%w[kind]])

        assert_equal({"kind" => "site"}, coercer.call({"kind" => "SITE"}))
        assert_equal({"kind" => nil}, coercer.call({"kind" => ""}))
      end

      def test_case_insensitive_enum_folds_unicode
        coercer = Coercer.new(schema: object("street" => {"type" => "string", "enum" => %w[straße]}), explodes: {}, case_insensitive: Set[%w[street]])

        assert_equal({"street" => "straße"}, coercer.call({"street" => "STRASSE"}))
      end

      def test_explode_defaults_to_configuration
        coercer = Coercer.new(schema: object("tags" => {"type" => "array"}), explodes: {})

        with_configuration(query_array_explode: false) do
          assert_equal({"tags" => %w[a b]}, coercer.call({"tags" => "a,b"}))
        end

        assert_equal({"tags" => ["a,b"]}, coercer.call({"tags" => "a,b"}))
      end

      def test_deep_object
        schema = object("filter" => object("page" => {"type" => "integer"}, "status" => {"type" => "array"}))
        coercer = Coercer.new(schema:, explodes: {%w[filter status] => false})

        assert_equal({"filter" => {"page" => 2, "status" => %w[a b]}}, coercer.call({"filter" => {"page" => "2", "status" => "a,b"}}))
      end

      def test_nullable_object
        schema = object("filter" => {"anyOf" => [object("page" => {"type" => "integer"}), {"type" => "null"}]})
        coercer = Coercer.new(schema:, explodes: {})

        assert_equal({"filter" => {"page" => 2}}, coercer.call({"filter" => {"page" => "2"}}))
        assert_equal({"filter" => nil}, coercer.call({"filter" => ""}))
      end

      def test_additional_properties_schema
        schema = object({}).merge("additionalProperties" => {"type" => "integer"})

        assert_equal({"a" => 1}, Coercer.new(schema:, explodes: {}).call({"a" => "1"}))
      end

      def test_unknown_and_symbol_keys
        coercer = Coercer.new(schema: object("page" => {"type" => "integer"}), explodes: {})

        assert_equal({:page => 1, "other" => "1"}, coercer.call({:page => "1", "other" => "1"}))
      end

      def test_object_without_properties
        coercer = Coercer.new(schema: {"type" => "object"}, explodes: {})

        assert_equal({"page" => "1"}, coercer.call({"page" => "1"}))
      end

      def test_input_is_not_modified
        params = {"filter" => {"page" => "2"}.freeze}.freeze
        schema = object("filter" => object("page" => {"type" => "integer"}))

        assert_equal({"filter" => {"page" => 2}}, Coercer.new(schema:, explodes: {}).call(params))
        assert_equal({"filter" => {"page" => "2"}}, params)
      end

      private

      def object(properties)
        {"type" => "object", "properties" => properties}
      end
    end
  end
end

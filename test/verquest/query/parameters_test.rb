# frozen_string_literal: true

require "test_helper"

module Verquest
  module Query
    class ParametersTest < Minitest::Test
      include ConfigurationTestHelper

      SCHEMA = {
        "type" => "object",
        "required" => %w[page],
        "properties" => {
          "page" => {"type" => "integer", "minimum" => 1, "description" => "Page"},
          "status" => {"type" => "array", "deprecated" => true, "items" => {"type" => "string", "enum" => %w[open won]}},
          "filter" => {"type" => "object", "properties" => {"after" => {"type" => "string"}}},
          "contact" => {"anyOf" => [{"type" => "object"}, {"type" => "null"}]},
          "tags" => {"type" => %w[array null], "examples" => [%w[a]]}
        }
      }.freeze

      def test_call
        expected = [
          {name: "page", in: :query, required: true, description: "Page", schema: {type: "integer", minimum: 1}},
          {name: "status", in: :query, required: false, deprecated: true, style: :form, explode: false, schema: {type: "array", items: {type: "string", enum: %w[open won]}}},
          {name: "filter", in: :query, required: false, style: :deepObject, explode: true, schema: {type: "object", properties: {after: {type: "string"}}}},
          {name: "contact", in: :query, required: false, style: :deepObject, explode: true, schema: {anyOf: [{type: "object"}, {type: "null"}]}},
          {name: "tags", in: :query, required: false, style: :form, explode: true, schema: {type: %w[array null], examples: [%w[a]]}}
        ]

        assert_equal expected, Parameters.new(schema: SCHEMA, options: {%w[status] => {explode: false}}).call
      end

      def test_explode_defaults_to_configuration
        with_configuration(query_array_explode: false) do
          tags = Parameters.new(schema: SCHEMA, options: {}).call.find { |parameter| parameter[:name] == "tags" }

          refute tags[:explode]
        end
      end

      def test_examples
        options = {%w[page] => {examples: {"single" => {"value" => 1}}}, %w[status] => {explode: false, examples: {single: {value: %w[open]}}}}
        examples = Parameters.new(schema: SCHEMA, options:).call.to_h { |parameter| [parameter[:name], parameter[:examples]] }

        assert_equal({"page" => {single: {value: 1}}, "status" => {single: {value: %w[open]}}, "filter" => nil, "contact" => nil, "tags" => nil}, examples)
      end

      def test_path_location
        schema = {"type" => "object", "required" => %w[id], "properties" => {"id" => {"type" => "string", "pattern" => "^deal_", "description" => "Deal"}}}

        expected = [{name: "id", in: :path, required: true, description: "Deal", schema: {type: "string", pattern: "^deal_"}}]

        assert_equal expected, Parameters.new(schema:, options: {}, location: :path).call
      end

      def test_schema_without_properties
        assert_empty Parameters.new(schema: {"type" => "object"}, options: {}).call
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/list_query"

module Verquest
  class QueryParamsTest < Minitest::Test
    include ConfigurationTestHelper

    PARAMS = {
      "page" => "2",
      "archived" => "true",
      "status" => "open,won",
      "site_id" => ["site_1"],
      "expand" => "contact,site",
      "created" => {"after" => "2025-01-01T00:00:00Z"}
    }.freeze

    def test_process
      expected = {
        "expand" => %w[contact site],
        "page" => 2,
        "archived" => true,
        "sort_direction" => "DESC",
        "status" => %w[open won],
        "site_ids" => ["site_1"],
        "created_after" => "2025-01-01T00:00:00Z"
      }

      assert_equal expected, ListQuery.process(PARAMS, version: "2025-06")
    end

    def test_process_inserts_typed_defaults
      assert_equal({"page" => 1, "sort_direction" => "DESC"}, ListQuery.process({}, version: "2025-06"))
    end

    def test_invalid_values
      error = assert_raises(InvalidParamsError) do
        ListQuery.process({"page" => "x", "status" => "open,closed"}, version: "2025-06")
      end

      assert_equal %w[/page /status/1], error.errors.map { |e| e[:pointer] }.sort
    end

    def test_invalid_values_as_result
      with_configuration(validation_error_handling: :result) do
        result = ListQuery.process({"archived" => "yes"}, version: "2025-06")

        assert_predicate result, :failure?
        assert_equal ["/archived"], result.errors.map { |e| e[:pointer] }
      end
    end

    def test_later_version_inherits_and_adds
      assert_equal "deal", ListQuery.process({"search" => "deal", "page" => "3"}, version: "2025-08")["search"]

      assert_raises(InvalidParamsError) do
        ListQuery.process({"search" => "deal"}, version: "2025-06", remove_extra_root_keys: false)
      end
    end

    def test_params_are_not_modified
      params = PARAMS.dup

      ListQuery.process(params, version: "2025-06")

      assert_equal PARAMS, params
    end

    def test_to_parameters
      parameters = ListQuery.to_parameters(version: "2025-06").to_h { |parameter| [parameter[:name], parameter] }

      expected = {
        "expand" => {name: "expand", in: :query, required: false, description: "Related resources to expand", style: :form, explode: false, schema: {type: "array", items: {type: "string"}}},
        "page" => {name: "page", in: :query, required: false, schema: {type: "integer", minimum: 1, default: 1}},
        "site_id" => [:form, true],
        "created" => [:deepObject, true]
      }
      actual = {
        "expand" => parameters["expand"],
        "page" => parameters["page"],
        "site_id" => parameters["site_id"].values_at(:style, :explode),
        "created" => parameters["created"].values_at(:style, :explode)
      }

      assert_equal %w[expand page archived sort_direction status site_id created], parameters.keys
      assert_equal expected, actual
    end

    def test_parameter_examples
      examples = ListQuery.to_parameters(version: "2025-06").to_h { |parameter| [parameter[:name], parameter[:examples]] }.compact
      schemas = [ListQuery.to_schema(version: "2025-06"), ListQuery.to_validation_schema(version: "2025-06")]

      assert_equal({"archived" => {archived: {value: true}}, "status" => {single: {value: %w[open]}, multiple: {value: %w[open won]}}}, examples)
      assert(schemas.none? { |schema| schema["properties"].values.any? { |property| property.key?("examples") } })
    end

    def test_valid_schema
      assert ListQuery.valid_schema?(version: "2025-06")
      assert ListQuery.valid_schema?(version: "2025-08")
    end
  end
end

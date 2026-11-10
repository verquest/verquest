# frozen_string_literal: true

require "test_helper"

module Verquest
  class CaseInsensitiveEnumTest < Minitest::Test
    include ConfigurationTestHelper

    QUERY = Class.new(Verquest::Base) do
      location :query

      version "2025-06" do
        field :sort_direction, type: :string, enum: %w[ASC DESC], case_insensitive: true
        enum :kind, values: %w[unit site], case_insensitive: true
        enum :strict, values: %w[unit site]
        filter :status, as: :array, type: :string, explode: false, item_schema_options: {enum: %w[open won]}, case_insensitive: true do |target, value|
          target.select { |item| value.include?(item) }
        end
      end
    end

    SORTING = Class.new(Verquest::Base) do
      location :query

      version("2025-06") { field :sort_direction, type: :string, enum: %w[ASC DESC], case_insensitive: true }
    end

    REFERENCING = Class.new(Verquest::Base) do
      location :query

      version "2025-06" do
        reference :sort_direction, from: SORTING, property: :sort_direction
        reference :fallback_direction, from: SORTING, property: :sort_direction, nullable: true
      end
    end

    UNSUPPORTED = {
      "const" => [proc { const :kind, value: "unit", case_insensitive: true }, "kind"],
      "object" => [proc { object(:filter, case_insensitive: true) { field :kind, type: :string } }, "filter"],
      "collection" => [proc { collection(:items, case_insensitive: true) { field :id, type: :string } }, "items"]
    }.freeze

    def test_reference_keeps_the_option
      params = {"sort_direction" => "desc", "fallback_direction" => "Asc"}

      assert_equal({"sort_direction" => "DESC", "fallback_direction" => "ASC"}, REFERENCING.process(params, version: "2025-06"))
    end

    def test_strict_reads_the_declared_value
      params = {"sort_direction" => "desc", "kind" => "Site", "status" => "OPEN,won"}

      assert_equal({"sort_direction" => "DESC", "kind" => "site", "status" => %w[open won]}, QUERY.process(params, version: "2025-06"))
    end

    def test_strict_rejects_a_value_without_a_match
      error = assert_raises(InvalidParamsError) { QUERY.process({"sort_direction" => "up"}, version: "2025-06") }

      assert_equal ["/sort_direction"], error.errors.map { |e| e[:pointer] }
    end

    def test_strict_without_the_option_still_rejects_another_case
      assert_raises(InvalidParamsError) { QUERY.process({"strict" => "UNIT"}, version: "2025-06") }
    end

    def test_lenient_reports_no_correction
      corrections = []
      result = with_configuration(lenient_through: "2025-06") do
        QUERY.process({"sort_direction" => "Asc", "strict" => "UNIT"}, version: "2025-06") { |correction| corrections << correction }
      end

      assert_equal({"sort_direction" => "ASC", "strict" => "unit"}, result)
      assert_equal [Correction.new(path: "/strict", rule: :enum_case, from: "UNIT", to: "unit")], corrections
    end

    def test_lenient_still_removes_a_value_without_a_match
      corrections = []
      result = with_configuration(lenient_through: "2025-06") do
        QUERY.process({"sort_direction" => "up"}, version: "2025-06") { |correction| corrections << correction }
      end

      assert_empty result
      assert_equal [:invalid], corrections.map(&:rule)
    end

    def test_filter_reads_the_declared_value
      params = QUERY.process({"status" => "Won"}, version: "2025-06")

      assert_equal %w[won], QUERY.apply_filters(%w[open won lost], params, version: "2025-06")
    end

    def test_parameters_list_only_the_declared_values
      parameters = QUERY.to_parameters(version: "2025-06")

      assert_equal %w[ASC DESC], parameters.find { |p| p[:name] == "sort_direction" }.dig(:schema, :enum)
      assert_equal %w[open won], parameters.find { |p| p[:name] == "status" }.dig(:schema, :items, :enum)
    end

    def test_schemas_leave_out_the_option
      documented = [QUERY.to_parameters(version: "2025-06"), QUERY.to_schema(version: "2025-06"), QUERY.to_validation_schema(version: "2025-06")]

      refute_match(/case_?insensitive/i, documented.to_s)
    end

    def test_body_class_raises
      error = assert_raises(DefinitionError) do
        Class.new(Verquest::Base) do
          version("2025-06") { field :kind, type: :string, enum: %w[unit site], case_insensitive: true }
        end
      end

      assert_equal "Property 'kind' in version '2025-06' is case_insensitive, which only query and path parameters support", error.message
    end

    def test_body_class_raises_for_properties_without_an_enum
      UNSUPPORTED.each do |label, (definition, name)|
        error = assert_raises(DefinitionError, label) { Class.new(Verquest::Base) { version("2025-06", &definition) } }

        assert_equal "Property '#{name}' in version '2025-06' is case_insensitive, which only query and path parameters support", error.message, label
      end
    end

    def test_with_options_raises
      error = assert_raises(DefinitionError) do
        Class.new(Verquest::Base) do
          location :query
          version("2025-06") { with_options(case_insensitive: true) { field :kind, type: :string, enum: %w[unit site] } }
        end
      end

      assert_equal "case_insensitive can't be set with with_options, set it on each property", error.message
    end

    def test_a_value_other_than_a_boolean_raises
      error = assert_raises(DefinitionError) do
        Class.new(Verquest::Base) do
          location :query
          version("2025-06") { field :kind, type: :string, enum: %w[unit site], case_insensitive: "no" }
        end
      end

      assert_equal "Property 'kind' in version '2025-06' has case_insensitive: \"no\", which must be true, false or nil", error.message
    end
  end
end

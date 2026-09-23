# frozen_string_literal: true

require "test_helper"

module Verquest
  class NullableDefaultsTest < Minitest::Test
    include ConfigurationTestHelper

    DEFAULTS = {
      "country" => "GB",
      "enabled" => false,
      "label" => nil,
      "kind" => "user",
      "flag" => false,
      "optional_kind" => nil
    }.freeze

    class Source < Verquest::Base
      version "2025-06" do
        field :country, type: :string, default: "GB"
        field :enabled, type: :boolean, default: false
        field :label, type: :string, nullable: true, default: nil
      end
    end

    class Request < Verquest::Base
      version "2025-06" do
        reference :country, from: Source, property: :country, nullable: true
        reference :enabled, from: Source, property: :enabled, nullable: true
        reference :label, from: Source, property: :label, nullable: true
        const :kind, value: "user", nullable: true, default: "user"
        const :flag, value: false, nullable: true, default: false
        const :optional_kind, value: "user", nullable: true, default: nil
        const :without_default, value: "user", nullable: true
      end
    end

    def test_missing_properties_receive_defaults
      with_configuration(insert_property_defaults: true) do
        assert_equal DEFAULTS, Request.process({}, version: "2025-06", validate: true)
      end
    end

    def test_explicit_null_values_are_not_replaced_by_defaults
      params = DEFAULTS.transform_values { nil }

      with_configuration(insert_property_defaults: true) do
        assert_equal params, Request.process(params, version: "2025-06", validate: true)
      end
    end

    def test_default_insertion_can_be_disabled
      with_configuration(insert_property_defaults: false) do
        assert_empty Request.process({}, version: "2025-06", validate: true)
      end
    end

    def test_validation_schema_keeps_defaults_on_outer_properties
      properties = Request.to_validation_schema(version: "2025-06")["properties"]

      assert_equal DEFAULTS, properties.filter_map { |name, schema| [name, schema["default"]] if schema.key?("default") }.to_h
      assert properties.values.none? { |schema| schema["anyOf"].first.key?("default") }
    end

    def test_exported_constant_schemas_keep_defaults_on_outer_properties
      properties = Request.to_schema(version: "2025-06")["properties"]
      expected = DEFAULTS.slice("kind", "flag", "optional_kind")

      assert_equal expected, properties.filter_map { |name, schema| [name, schema["default"]] if schema.key?("default") }.to_h
      refute properties["without_default"].key?("default")
    end

    def test_referenced_schema_defaults_are_not_removed
      properties = Source.to_validation_schema(version: "2025-06")["properties"]
      expected = DEFAULTS.slice("country", "enabled", "label")

      assert_equal expected, properties.transform_values { |schema| schema.fetch("default") }
    end

    def test_invalid_non_null_values_are_still_rejected
      assert_raises(InvalidParamsError) do
        Request.process({"kind" => "admin"}, version: "2025-06", validate: true)
      end
    end
  end
end

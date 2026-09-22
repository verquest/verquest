# frozen_string_literal: true

require "test_helper"
require "json"

module Verquest
  class NullableEnumTest < Minitest::Test
    class Request < Verquest::Base
      version "2025-06" do
        enum :role, values: %w[member admin], nullable: true, required: true
        enum :status, values: %w[active inactive]
      end
    end

    def test_exported_json_contains_null_value
      schema = JSON.parse(JSON.generate(Request.to_schema(version: "2025-06")))

      assert_equal ["member", "admin", nil], schema["properties"]["role"]["enum"]
      assert JSONSchemer.schema(schema).valid?({"role" => nil})
    end

    def test_validation_schema_accepts_null
      schema = Request.to_validation_schema(version: "2025-06")

      assert JSONSchemer.schema(schema).valid?({"role" => nil})
    end

    def test_process_preserves_null
      params = {"role" => nil}

      assert_equal params, Request.process(params, version: "2025-06", validate: true)
    end

    def test_process_accepts_declared_values
      %w[member admin].each do |role|
        params = {"role" => role}

        assert_equal params, Request.process(params, version: "2025-06", validate: true)
      end
    end

    def test_process_rejects_undeclared_values
      ["null", "guest", 1].each do |role|
        assert_raises(Verquest::InvalidParamsError) do
          Request.process({"role" => role}, version: "2025-06", validate: true)
        end
      end
    end

    def test_non_nullable_enum_rejects_null
      assert_raises(Verquest::InvalidParamsError) do
        Request.process({"role" => "member", "status" => nil}, version: "2025-06", validate: true)
      end
    end

    def test_required_nullable_enum_rejects_missing_key
      assert_raises(Verquest::InvalidParamsError) do
        Request.process({}, version: "2025-06", validate: true)
      end
    end
  end
end

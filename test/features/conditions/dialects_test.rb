# frozen_string_literal: true

require "test_helper"

module Verquest
  # Tests which JSON Schema versions support conditions
  class ConditionsDialectsTest < Minitest::Test
    include ConfigurationTestHelper

    def test_unsupported_dialects_raise
      messages = %i[draft4 draft6 openapi30].to_h do |dialect|
        error = assert_raises(ArgumentError) { build_request(dialect) }
        [dialect, error.message]
      end

      expected = %i[draft4 draft6 openapi30].to_h do |dialect|
        [dialect, "Conditions need json_schema_version draft7 or later, or openapi31 (got #{dialect})"]
      end

      assert_equal expected, messages
    end

    def test_schema_is_valid_for_supported_dialects
      valid = %i[draft7 draft2019_09 draft2020_12 openapi31].to_h do |dialect|
        request = build_request(dialect)
        [dialect, with_configuration(json_schema_version: dialect) { request.valid_schema?(version: "2025-09") }]
      end

      assert_equal({draft7: true, draft2019_09: true, draft2020_12: true, openapi31: true}, valid)
    end

    def test_requests_without_conditions_are_not_affected
      request = with_configuration(json_schema_version: :draft4) do
        Class.new(Verquest::Base) do
          version("2025-09") { field :kind, type: :string }
        end
      end

      assert_equal %w[kind], request.to_schema(version: "2025-09")["properties"].keys
    end

    private

    def build_request(dialect)
      with_configuration(json_schema_version: dialect) do
        Class.new(Verquest::Base) do
          version "2025-09" do
            field :kind, type: :string
            object :customer do
              field :kind, type: :string
              depends_on(:kind) { field :vat_id, type: :string }
            end
            depends_on(:kind) { field :note, type: :string }
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

# Tests that const is enforced in JSON Schema versions without the const keyword
class Verquest::ConstJsonSchemaVersionTest < Minitest::Test
  include Verquest::ConfigurationTestHelper

  VERSIONS = %i[draft4 draft6 draft7 draft2019_09 draft2020_12 openapi30 openapi31].freeze

  def test_schema_keyword
    keywords = VERSIONS.to_h do |json_schema_version|
      request = build_request(json_schema_version)
      [json_schema_version, [request.to_schema(version: "2025-06"), request.to_validation_schema(version: "2025-06")].map { |schema| schema["properties"]["kind"] }]
    end

    expected = VERSIONS.to_h do |json_schema_version|
      keyword = %i[draft4 openapi30].include?(json_schema_version) ? {"enum" => ["dog"]} : {"const" => "dog"}
      [json_schema_version, [keyword, keyword]]
    end

    assert_equal expected, keywords
  end

  def test_validation_rejects_other_values
    results = VERSIONS.to_h do |json_schema_version|
      request = build_request(json_schema_version)
      valid = with_configuration(json_schema_version:, validation_error_handling: :result) { [{"kind" => "dog"}, {"kind" => "cat"}].map { |params| request.process(params, version: "2025-06").success? } }
      [json_schema_version, valid]
    end

    assert_equal VERSIONS.to_h { |json_schema_version| [json_schema_version, [true, false]] }, results
  end

  def test_nullable_const
    request = build_request(:openapi30, nullable: true)

    assert_equal({"anyOf" => [{"enum" => ["dog"]}, {"type" => "null"}]}, request.to_schema(version: "2025-06")["properties"]["kind"])
  end

  private

  def build_request(json_schema_version, nullable: false)
    with_configuration(json_schema_version:) do
      Class.new(Verquest::Base) do
        version("2025-06") { const :kind, value: "dog", nullable: }
      end
    end
  end
end

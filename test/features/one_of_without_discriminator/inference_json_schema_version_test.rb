# frozen_string_literal: true

require "test_helper"

# Tests that variant inference reads the variant schemas in the configured JSON Schema version
class Verquest::InferenceJsonSchemaVersionTest < Minitest::Test
  include Verquest::ConfigurationTestHelper

  def test_process_with_draft4_boolean_exclusive_maximum
    request = with_configuration(json_schema_version: :draft4) do
      Class.new(Verquest::Base) do
        version "2025-06" do
          one_of name: :value do
            object(:small) { field :amount, type: :number, required: true, maximum: 10, exclusive_maximum: true }
            object(:large) { field :amount, type: :number, required: true, minimum: 10, map: "large_amount" }
          end
        end
      end
    end

    results = [9, 10].to_h do |amount|
      [amount, with_configuration(json_schema_version: :draft4) { request.process({"value" => {"amount" => amount}}, version: "2025-06") }]
    end

    assert_equal({9 => {"value" => {"amount" => 9}}, 10 => {"value" => {"large_amount" => 10}}}, results)
  end
end

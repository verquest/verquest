# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/deal_path"

module Verquest
  class PathParamsTest < Minitest::Test
    def test_process
      assert_equal({"id" => "deal_1"}, DealPath.process({"id" => "deal_1"}, version: "2025-06"))
    end

    def test_invalid_prefix
      error = assert_raises(InvalidParamsError) { DealPath.process({"id" => "con_1"}, version: "2025-06") }

      assert_equal ["/id"], error.errors.map { |e| e[:pointer] }
    end

    def test_missing_id
      assert_raises(InvalidParamsError) { DealPath.process({}, version: "2025-06") }
    end

    def test_to_parameters
      expected = [{
        name: "id",
        in: :path,
        required: true,
        description: "The ID of the deal",
        examples: {deal: {value: "deal_0123456789abcdef"}},
        schema: {type: "string", pattern: "^deal_"}
      }]

      assert_equal expected, DealPath.to_parameters(version: "2025-06")
    end
  end
end

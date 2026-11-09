# frozen_string_literal: true

require "test_helper"

module Verquest
  module Query
    class LenientCoercerTest < Minitest::Test
      SCHEMA = {
        "type" => "object",
        "properties" => {
          "price" => {"type" => "number", "maximum" => 10},
          "name" => {"type" => "string", "format" => "date-time"},
          "size" => {"anyOf" => [{"type" => "integer"}, {"type" => "null"}]},
          "code" => {"anyOf" => [{"type" => "integer"}, {"type" => "string"}]},
          "created" => {"type" => "object", "properties" => {"after" => {"type" => "integer"}}}
        }
      }.freeze

      def coerce(params, on_correction: nil)
        LenientCoercer.new(schema: SCHEMA, explodes: {}, required: [], on_correction:).call(params)
      end

      def test_numbers_above_the_maximum_are_capped
        corrections = []

        assert_equal({"price" => 10}, coerce({"price" => "12.5"}, on_correction: ->(correction) { corrections << correction }))
        assert_equal [Correction.new(path: "/price", rule: :maximum, from: "12.5", to: 10)], corrections
      end

      def test_a_blank_value_a_variant_accepts_is_kept
        assert_equal({"size" => nil}, coerce({"size" => ""}))
      end

      def test_a_blank_value_a_string_variant_accepts_is_kept
        corrections = []

        assert_equal({"code" => ""}, coerce({"code" => ""}, on_correction: ->(correction) { corrections << correction }))
        assert_empty corrections
      end

      def test_values_that_are_not_strings_are_left_for_validation
        assert_equal({"name" => 5}, coerce({"name" => 5}))
      end

      # Only root values are removed when blank; nested values are converted like Coercer does
      def test_nested_values_are_converted_but_not_removed
        assert_equal({"created" => {"after" => ""}}, coerce({"created" => {"after" => ""}}))
        assert_equal({"created" => {"after" => 3}}, coerce({"created" => {"after" => "3"}}))
      end

      def test_corrects_without_a_callback
        assert_empty coerce({"name" => ""})
      end

      def test_a_correction_pointer_is_escaped
        corrections = []
        schema = {"type" => "object", "properties" => {"a/b~c" => {"type" => "integer", "maximum" => 1}}}

        LenientCoercer.new(schema:, explodes: {}, required: [], on_correction: ->(correction) { corrections << correction }).call({"a/b~c" => "5"})

        assert_equal ["/a~1b~0c"], corrections.map(&:path)
        assert_equal ["a/b~c"], corrections.map(&:name)
      end
    end
  end
end

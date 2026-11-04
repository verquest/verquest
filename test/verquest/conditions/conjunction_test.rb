# frozen_string_literal: true

require "test_helper"

module Verquest
  module Conditions
    class ConjunctionTest < Minitest::Test
      def test_merges_fragments_that_do_not_clash
        fragments = [
          {"required" => ["a"], "properties" => {"a" => {"type" => "string"}}},
          {"required" => ["b"], "properties" => {"a" => {"const" => "x"}}}
        ]

        expected = {"required" => %w[a b], "properties" => {"a" => {"type" => "string", "const" => "x"}}}

        assert_equal expected, Conjunction.call(fragments)
      end

      def test_moves_a_clashing_fragment_into_all_of
        fragments = [
          {"properties" => {"note" => {"type" => "string"}, "age" => {"minimum" => 0}}},
          {"properties" => {"note" => false}},
          {"properties" => {"age" => {"minimum" => 18}}}
        ]

        expected = {
          "properties" => {"note" => {"type" => "string"}, "age" => {"minimum" => 0}},
          "allOf" => [{"properties" => {"note" => false}}, {"properties" => {"age" => {"minimum" => 18}}}]
        }

        assert_equal expected, Conjunction.call(fragments)
      end
    end
  end
end

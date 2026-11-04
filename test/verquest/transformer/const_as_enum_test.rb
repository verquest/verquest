# frozen_string_literal: true

require "test_helper"

module Verquest
  class Transformer
    class ConstAsEnumTest < Minitest::Test
      def test_call
        schema = {
          "type" => "object",
          "properties" => {
            "const" => {"const" => "a"},
            "kind" => {"enum" => [{"const" => "data"}], "default" => {"const" => "data"}},
            "shape" => {"oneOf" => [{"const" => 1}, {"type" => "null"}]},
            "items" => {"type" => "array", "items" => {"properties" => {"type" => {"const" => "b"}}}}
          },
          "definitions" => {"const" => {"const" => true}}
        }

        expected = {
          "type" => "object",
          "properties" => {
            "const" => {"enum" => ["a"]},
            "kind" => {"enum" => [{"const" => "data"}], "default" => {"const" => "data"}},
            "shape" => {"oneOf" => [{"enum" => [1]}, {"type" => "null"}]},
            "items" => {"type" => "array", "items" => {"properties" => {"type" => {"enum" => ["b"]}}}}
          },
          "definitions" => {"const" => {"enum" => [true]}}
        }

        assert_equal expected, ConstAsEnum.call(schema)
      end
    end
  end
end

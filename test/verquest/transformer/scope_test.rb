# frozen_string_literal: true

require "test_helper"

module Verquest
  class Transformer
    class ScopeTest < Minitest::Test
      def test_variant_scope_writes_into_the_parent_result
        dog = Scope.new(pairs: [[Path.new("pet/bark"), Path.new("pet/woof")]], one_ofs: [], collections: [])
        one_of = OneOf.new(path: Path.new("pet"), discriminator: Path.new("pet/type"), variants: {"dog" => dog})
        scope = Scope.new(pairs: [[Path.new("id"), Path.new("id")]], one_ofs: [one_of], collections: [])

        assert_equal({"id" => "1", "pet" => {"woof" => true}}, scope.call({"id" => "1", "pet" => {"type" => "dog", "bark" => true}}))
      end

      def test_absent_and_null_one_of_variants
        dog = Scope.new(pairs: [[Path.new("pet/bark"), Path.new("pet/woof")]], one_ofs: [], collections: [])
        one_of = OneOf.new(path: Path.new("pet"), discriminator: Path.new("pet/type"), variants: {"dog" => dog})
        scope = Scope.new(pairs: [[Path.new("id"), Path.new("id")]], one_ofs: [one_of], collections: [])

        results = {absent: scope.call({"id" => "1"}), null: scope.call({"id" => "1", "pet" => nil})}

        assert_equal({absent: {"id" => "1"}, null: {"id" => "1", "pet" => nil}}, results)
      end
    end
  end
end

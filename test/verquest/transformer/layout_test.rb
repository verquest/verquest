# frozen_string_literal: true

require "test_helper"

module Verquest
  class Transformer
    class LayoutTest < Minitest::Test
      def test_collects_pairs_one_ofs_and_collections
        layout = Layout.new
        layout.add_collection("pets[]", "animals[]")
        variant = layout.variant
        variant.add_pair("pets[]/kind/bark", "animals[]/kind/woof")
        variant.add_collection("pets[]/kind/toys[]", "animals[]/kind/toys[]")
        one_of = Layout::OneOfLayout.new(path: "pets[]/kind", discriminator: "pets[]/kind/type", variants: {"dog" => variant}, variant_schemas: nil, null_target: nil)
        layout.add_pair("id", "id")
        layout.add_one_of(one_of)

        # A variant copies its parent's collections, and its own stay in the variant
        expected = {
          pairs: {"id" => "id"},
          one_ofs: [one_of],
          collections: {"pets[]" => "animals[]"},
          variant_pairs: {"pets[]/kind/bark" => "animals[]/kind/woof"},
          variant_collections: {"pets[]" => "animals[]", "pets[]/kind/toys[]" => "animals[]/kind/toys[]"}
        }

        assert_equal expected, {pairs: layout.pairs, one_ofs: layout.one_ofs, collections: layout.collections, variant_pairs: variant.pairs, variant_collections: variant.collections}
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class Verquest::Transformer::PlanTest < Minitest::Test
  def test_raises_when_the_layout_misses_a_collection
    layout = Verquest::Transformer::Layout.new
    layout.add_one_of(Verquest::Transformer::Layout::OneOfLayout.new(path: "pets[]", discriminator: "pets[]/type", variants: {}, variant_schemas: nil, null_target: nil))

    error = assert_raises(ArgumentError) { Verquest::Transformer::Plan.new(layout) }

    assert_equal "The layout doesn't list the collection pets[]", error.message
  end
end

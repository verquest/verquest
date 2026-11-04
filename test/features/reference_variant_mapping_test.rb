# frozen_string_literal: true

require "test_helper"

# Tests the mapping of oneOf reference variants
class Verquest::ReferenceVariantMappingTest < Minitest::Test
  class RelativeComponent < Verquest::Base
    version "2025-06" do
      const :kind, value: "relative"
      field :a, type: :string, map: "b"
    end
  end

  class AbsoluteComponent < Verquest::Base
    version "2025-06" do
      const :kind, value: "absolute"
      field :a, type: :string, map: "/top_a"
    end
  end

  class RootedComponent < Verquest::Base
    version "2025-06" do
      const :kind, value: "rooted"
      field :a, type: :string
    end
  end

  class PetsComponent < Verquest::Base
    version "2025-06" do
      field :name, type: :string

      collection :pets do
        one_of name: :pet, discriminator: :type do
          object :dog do
            const :type, value: "dog"
            field :bark, type: :boolean, map: "woof"
          end

          object :cat do
            const :type, value: "cat"
          end
        end
      end
    end
  end

  class ThingRequest < Verquest::Base
    version "2025-06" do
      one_of name: :thing, discriminator: :kind do
        reference :relative, from: RelativeComponent, map: "m"
        reference :absolute, from: AbsoluteComponent, map: "m"
        reference :rooted, from: RootedComponent, map: "/r"
      end
    end
  end

  class PartyRequest < Verquest::Base
    version "2025-06" do
      one_of name: :party do
        reference :pets, from: PetsComponent
      end
    end
  end

  def test_mapping_with_map
    expected = {
      mapping: {
        "relative" => {"thing/kind" => "thing/m/kind", "thing/a" => "thing/m/b"},
        "absolute" => {"thing/kind" => "thing/m/kind", "thing/a" => "top_a"},
        "rooted" => {"thing/kind" => "r/kind", "thing/a" => "r/a"},
        "_discriminator" => "thing/kind"
      },
      relative: {"thing" => {"m" => {"kind" => "relative", "b" => "x"}}},
      absolute: {"thing" => {"m" => {"kind" => "absolute"}}, "top_a" => "y"},
      rooted: {"r" => {"kind" => "rooted", "a" => "z"}}
    }

    actual = {
      mapping: ThingRequest.mapping(version: "2025-06"),
      relative: ThingRequest.process({"thing" => {"kind" => "relative", "a" => "x"}}, version: "2025-06"),
      absolute: ThingRequest.process({"thing" => {"kind" => "absolute", "a" => "y"}}, version: "2025-06"),
      rooted: ThingRequest.process({"thing" => {"kind" => "rooted", "a" => "z"}}, version: "2025-06")
    }

    assert_equal expected, actual
  end

  def test_mapping_with_collection_of_one_ofs
    expected = {
      "party/name" => "party/name",
      "_oneOfs" => [{
        "dog" => {"party/pets[]/pet/type" => "party/pets[]/pet/type", "party/pets[]/pet/bark" => "party/pets[]/pet/woof"},
        "cat" => {"party/pets[]/pet/type" => "party/pets[]/pet/type"},
        "_discriminator" => "party/pets[]/pet/type"
      }]
    }

    assert_equal expected, PartyRequest.mapping(version: "2025-06")["pets"]
  end
end

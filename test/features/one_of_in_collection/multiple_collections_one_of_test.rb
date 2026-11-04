# frozen_string_literal: true

require "test_helper"

# Tests a version with several collections whose items hold a oneOf
class Verquest::MultipleCollectionsOneOfTest < Minitest::Test
  class ShelterRequest < Verquest::Base
    version "2025-06" do
      field :id, type: :string

      collection :pets do
        field :name, type: :string

        one_of name: :kind, discriminator: :type do
          object :dog do
            const :type, value: "dog"
            field :bark, type: :boolean
          end

          object :cat do
            const :type, value: "cat"
            field :meow, type: :boolean
          end
        end
      end

      collection :entries do
        field :entry_id, type: :string

        one_of name: :content do
          object(:text) { field :text, type: :string, required: true }
          object(:number) { field :amount, type: :number, required: true, map: "total" }
        end
      end

      collection :shapes do
        one_of discriminator: :kind do
          object :square do
            const :kind, value: "square"
            field :side, type: :number
          end

          object :circle do
            const :kind, value: "circle"
            field :radius, type: :number
          end
        end
      end
    end
  end

  def test_process
    params = {
      "id" => "1",
      "pets" => [{"name" => "Rex", "kind" => {"type" => "dog", "bark" => true}}, {"kind" => {"type" => "cat", "meow" => false}}],
      "entries" => [{"entry_id" => "1", "content" => {"text" => "t"}}, {"entry_id" => "2", "content" => {"amount" => 2}}],
      "shapes" => [{"kind" => "circle", "radius" => 1}]
    }

    expected = params.merge("entries" => [{"entry_id" => "1", "content" => {"text" => "t"}}, {"entry_id" => "2", "content" => {"total" => 2}}])

    assert_equal expected, ShelterRequest.process(params, version: "2025-06")
  end

  def test_external_mapping
    external = ShelterRequest.external_mapping(version: "2025-06")

    assert_equal({"id" => "id", "pets[]/name" => "pets[]/name", "entries[]/entry_id" => "entries[]/entry_id"}, external.except("_oneOfs"))
    assert_equal({"entries[]/content/total" => "entries[]/content/amount"}, external["_oneOfs"][1]["number"])
  end
end

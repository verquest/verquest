# frozen_string_literal: true

require "test_helper"

# Tests that collection items keep their position and their null objects
class Verquest::CollectionItemsMappingTest < Minitest::Test
  class ItemsRequest < Verquest::Base
    version "2025-06" do
      collection :items do
        field :name, type: :string, map: "title"

        object :meta, nullable: true do
          field :note, type: :string
        end
      end
    end
  end

  def test_process
    cases = {
      "empty first item" => [
        {"items" => [{}, {"name" => "b"}]},
        {"items" => [{}, {"title" => "b"}]}
      ],
      "only empty items" => [
        {"items" => [{}, {}]},
        {"items" => [{}, {}]}
      ],
      "null object in item" => [
        {"items" => [{"name" => "a", "meta" => nil}, {"meta" => {"note" => "n"}}]},
        {"items" => [{"title" => "a", "meta" => nil}, {"meta" => {"note" => "n"}}]}
      ],
      "empty collection" => [
        {"items" => []},
        {"items" => []}
      ]
    }

    results = cases.transform_values { |(params, _)| ItemsRequest.process(params, version: "2025-06") }

    assert_equal cases.transform_values(&:last), results
  end
end

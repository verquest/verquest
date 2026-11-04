# frozen_string_literal: true

require "test_helper"

# Tests oneOfs in collections inside collections, and properties moved out of collection items
class Verquest::NestedCollectionOneOfTest < Minitest::Test
  class GroupsRequest < Verquest::Base
    version "2025-06" do
      collection :groups, map: "teams" do
        field :label, type: :string

        collection :pets, map: "animals" do
          field :tag, type: :string, map: "/tags"

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
      end
    end
  end

  class EntriesRequest < Verquest::Base
    version "2025-06" do
      collection :groups do
        collection :entries do
          field :entry_id, type: :string

          one_of name: :content do
            object(:text) { field :text, type: :string, required: true }
            object(:number) { field :amount, type: :number, required: true, map: "total" }
          end
        end
      end
    end
  end

  def test_process
    cases = {
      "discriminated" => [
        GroupsRequest,
        {"groups" => [
          {"label" => "a", "pets" => [{"tag" => "t1", "kind" => {"type" => "dog", "bark" => true}}, {"kind" => {"type" => "cat", "meow" => false}}]},
          {"label" => "b", "pets" => []}
        ]},
        {"teams" => [
          {"label" => "a", "animals" => [{"kind" => {"type" => "dog", "bark" => true}}, {"kind" => {"type" => "cat", "meow" => false}}]},
          {"label" => "b", "animals" => []}
        ], "tags" => [["t1", nil], []]}
      ],
      "inferred" => [
        EntriesRequest,
        {"groups" => [{"entries" => [{"entry_id" => "1", "content" => {"text" => "t"}}, {"entry_id" => "2", "content" => {"amount" => 1}}]}]},
        {"groups" => [{"entries" => [{"entry_id" => "1", "content" => {"text" => "t"}}, {"entry_id" => "2", "content" => {"total" => 1}}]}]}
      ]
    }

    results = cases.transform_values { |(request, params, _)| request.process(params, version: "2025-06") }

    assert_equal cases.transform_values(&:last), results
  end

  def test_variant_property_moved_out_of_a_collection_item_raises
    error = assert_raises(Verquest::MappingError) do
      Class.new(Verquest::Base) do
        version "2025-06" do
          collection :pets do
            one_of discriminator: :type do
              object :dog do
                const :type, value: "dog"
                field :bark, type: :boolean, map: "/barks"
              end

              object :cat do
                const :type, value: "cat"
              end
            end
          end
        end
      end
    end

    assert_equal "map: can't move a oneOf variant property out of its collection item (pets[]/bark => barks)", error.message
  end
end

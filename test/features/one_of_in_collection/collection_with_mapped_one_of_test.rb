# frozen_string_literal: true

require "test_helper"

# Tests a collection with a oneOf, renamed with map:
class Verquest::CollectionWithMappedOneOfTest < Minitest::Test
  class NamedOneOfRequest < Verquest::Base
    version "2025-06" do
      collection :entries, map: "records" do
        field :entry_id, type: :string

        one_of name: :content, nullable: true do
          object(:text) { field :text, type: :string, required: true }
          object(:number) { field :amount, type: :number, required: true }
        end
      end
    end
  end

  class DiscriminatedOneOfRequest < Verquest::Base
    version "2025-06" do
      collection :pets, map: "animals" do
        one_of discriminator: :type do
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

  def test_process
    cases = {
      "named oneOf" => [
        NamedOneOfRequest,
        {"entries" => [{"entry_id" => "1", "content" => {"amount" => 2}}, {"entry_id" => "2", "content" => nil}]},
        {"records" => [{"entry_id" => "1", "content" => {"amount" => 2}}, {"entry_id" => "2", "content" => nil}]}
      ],
      "discriminated oneOf" => [
        DiscriminatedOneOfRequest,
        {"pets" => [{"type" => "dog", "bark" => true}, {"type" => "cat"}]},
        {"animals" => [{"type" => "dog", "bark" => true}, {"type" => "cat"}]}
      ]
    }

    results = cases.transform_values { |(request, params, _)| request.process(params, version: "2025-06") }

    assert_equal cases.transform_values(&:last), results
  end
end

# frozen_string_literal: true

require "test_helper"

# Tests collection items whose optional or nullable oneOf is missing or null
class Verquest::CollectionWithOptionalOneOfTest < Minitest::Test
  class EntriesRequest < Verquest::Base
    version "2025-06" do
      collection :entries do
        field :entry_id, type: :string, map: "id"

        one_of name: :content, nullable: true, map: "body" do
          object :text do
            field :text, type: :string, required: true
          end

          object :number do
            field :amount, type: :number, required: true
          end
        end
      end
    end
  end

  def test_process
    cases = {
      "missing oneOf" => [
        {"entries" => [{"entry_id" => "1"}, {"entry_id" => "2", "content" => {"amount" => 3}}]},
        {"entries" => [{"id" => "1"}, {"id" => "2", "body" => {"amount" => 3}}]}
      ],
      "null oneOf" => [
        {"entries" => [{"entry_id" => "1", "content" => nil}]},
        {"entries" => [{"id" => "1", "body" => nil}]}
      ]
    }

    results = cases.transform_values { |(params, _)| EntriesRequest.process(params, version: "2025-06") }

    assert_equal cases.transform_values(&:last), results
  end
end

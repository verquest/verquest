# frozen_string_literal: true

require "test_helper"

# Tests that property names starting with an underscore are mapped next to oneOfs
class Verquest::UnderscorePropertyNamesTest < Minitest::Test
  class SingleOneOfRequest < Verquest::Base
    version "2025-06" do
      field :_ref, type: :string

      one_of name: :value do
        object :text do
          field :_text, type: :string, required: true
        end

        object :number do
          field :amount, type: :number, required: true
        end
      end
    end
  end

  class MultipleOneOfRequest < Verquest::Base
    version "2025-06" do
      field :_ref, type: :string, map: "_reference"

      one_of name: :a do
        object(:text) { field :content, type: :string, required: true }
        object(:number) { field :amount, type: :number, required: true }
      end

      one_of name: :b do
        object(:text) { field :content, type: :string, required: true }
        object(:number) { field :amount, type: :number, required: true }
      end
    end
  end

  class CollectionOneOfRequest < Verquest::Base
    version "2025-06" do
      field :_ref, type: :string

      collection :entries do
        field :_entry, type: :string

        one_of name: :content do
          object(:text) { field :content, type: :string, required: true }
          object(:number) { field :amount, type: :number, required: true }
        end
      end
    end
  end

  def test_process
    cases = {
      SingleOneOfRequest => [{"_ref" => "r", "value" => {"_text" => "x"}}] * 2,
      MultipleOneOfRequest => [{"_ref" => "r", "a" => {"amount" => 1}, "b" => {"content" => "x"}}, {"_reference" => "r", "a" => {"amount" => 1}, "b" => {"content" => "x"}}],
      CollectionOneOfRequest => [{"_ref" => "r", "entries" => [{"_entry" => "e", "content" => {"amount" => 1}}]}] * 2
    }

    results = cases.to_h { |request, (params, _)| [request, request.process(params, version: "2025-06")] }

    assert_equal cases.transform_values(&:last), results
  end

  def test_external_mapping_inverts_underscore_properties
    assert_equal "_ref", MultipleOneOfRequest.external_mapping(version: "2025-06")["_reference"]
  end
end

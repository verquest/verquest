# frozen_string_literal: true

require "test_helper"

# Tests where an unnamed oneOf can be declared, and a named oneOf alone in a collection
class Verquest::UnnamedOneOfPlacementTest < Minitest::Test
  class EntriesRequest < Verquest::Base
    version "2025-06" do
      collection :entries do
        one_of name: :content do
          object(:text) { field :text, type: :string, required: true }
          object(:number) { field :amount, type: :number, required: true, map: "total" }
        end
      end
    end
  end

  def test_named_one_of_alone_in_a_collection_keeps_its_name
    items = EntriesRequest.to_validation_schema(version: "2025-06")["properties"]["entries"]["items"]
    params = {"entries" => [{"content" => {"text" => "t"}}, {"content" => {"amount" => 1}}]}

    assert_equal({"type" => "object", "keys" => %w[content]}, {"type" => items["type"], "keys" => items["properties"].keys})
    assert_equal({"entries" => [{"content" => {"text" => "t"}}, {"content" => {"total" => 1}}]}, EntriesRequest.process(params, version: "2025-06"))
  end

  def test_unnamed_one_of_next_to_other_properties_raises
    scopes = {
      "version" => lambda do |request|
        request.send(:version, "2025-06") do
          field :name, type: :string
          unnamed_one_of
        end
      end,
      "version, oneOf first" => lambda do |request|
        request.send(:version, "2025-06") do
          unnamed_one_of
          field :name, type: :string
        end
      end,
      "object" => lambda do |request|
        request.send(:version, "2025-06") do
          object :pet do
            field :name, type: :string
            unnamed_one_of
          end
        end
      end,
      "collection" => lambda do |request|
        request.send(:version, "2025-06") do
          collection :pets do
            field :name, type: :string
            unnamed_one_of
          end
        end
      end
    }

    messages = scopes.transform_values do |define|
      request = Class.new(Verquest::Base) do
        def self.unnamed_one_of
          one_of(discriminator: :type) do
            object(:dog) { const :type, value: "dog" }
            object(:cat) { const :type, value: "cat" }
          end
        end
      end
      define.call(request)
      nil
    rescue ArgumentError => e
      e.message
    end

    expected = "An unnamed one_of must be the only property in its scope. Give it a name: to declare it next to other properties"

    assert_equal scopes.transform_values { expected }, messages
  end
end

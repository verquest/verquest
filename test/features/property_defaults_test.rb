# frozen_string_literal: true

require "test_helper"

module Verquest
  # Tests that defaults are inserted wherever they are declared
  class PropertyDefaultsTest < Minitest::Test
    include ConfigurationTestHelper

    class Item < Verquest::Base
      version "2025-06" do
        field :name, type: :string, required: true
        field :qty, type: :integer, default: 1
      end
    end

    class Request < Verquest::Base
      version "2025-06" do
        object :settings do
          field :theme, type: :string, default: "light"
        end
        collection :items, item: Item
      end
    end

    class Dog < Verquest::Base
      version "2025-06" do
        const :type, value: "dog"
        field :name, type: :string, default: "Rex"
      end
    end

    class Cat < Verquest::Base
      version "2025-06" do
        const :type, value: "cat"
        field :name, type: :string
      end
    end

    class Pet < Verquest::Base
      version "2025-06" do
        one_of discriminator: :type do
          reference :dog, from: Dog
          reference :cat, from: Cat
        end
      end
    end

    def test_inserts_defaults_in_nested_objects_and_collection_items
      params = {"settings" => {}, "items" => [{"name" => "a"}, {"name" => "b", "qty" => 3}]}
      expected = {"settings" => {"theme" => "light"}, "items" => [{"name" => "a", "qty" => 1}, {"name" => "b", "qty" => 3}]}

      with_configuration(insert_property_defaults: true) do
        assert_equal expected, Request.process(params, version: "2025-06")
      end
    end

    def test_inserts_defaults_in_a_root_one_of_branch
      with_configuration(insert_property_defaults: true) do
        assert_equal({"type" => "dog", "name" => "Rex"}, Pet.process({"type" => "dog"}, version: "2025-06"))
      end
    end

    def test_leaves_the_callers_params_unchanged
      params = {"settings" => {}, "items" => [{"name" => "a"}]}

      with_configuration(insert_property_defaults: true) do
        result = Request.process(params, version: "2025-06")

        assert_equal({"settings" => {"theme" => "light"}, "items" => [{"name" => "a", "qty" => 1}]}, result)
      end
      assert_equal({"settings" => {}, "items" => [{"name" => "a"}]}, params)
    end

    def test_leaves_frozen_params_usable
      params = {"settings" => {}.freeze, "items" => [{"name" => "a"}.freeze].freeze}.freeze

      with_configuration(insert_property_defaults: true) do
        assert_equal({"settings" => {"theme" => "light"}, "items" => [{"name" => "a", "qty" => 1}]}, Request.process(params, version: "2025-06"))
      end
    end

    class NestedDefaultRequest < Verquest::Base
      version "2025-06" do
        object :settings, default: {"tags" => ["light"]} do
          array :tags, type: :string
        end
      end
    end

    def test_changing_an_inserted_default_leaves_later_requests_alone
      version = NestedDefaultRequest.send(:resolve, "2025-06")
      inserted = [true, :symbol].map do |insert_property_defaults|
        with_configuration(insert_property_defaults:) do
          2.times.map { {}.tap { |params| version.validate_params(params:) } }.each { |params| params.values.first["tags"] << "dark" }
        end
      end

      assert_equal [[{"settings" => {"tags" => %w[light dark]}}] * 2, [{settings: {"tags" => %w[light dark]}}] * 2], inserted
    end

    class StringDefaultRequest < Verquest::Base
      version "2025-06" do
        array :tags, type: :string, default: [+"light"]
      end
    end

    def test_changing_an_inserted_default_string_leaves_later_requests_alone
      with_configuration(insert_property_defaults: true) do
        StringDefaultRequest.process({}, version: "2025-06")["tags"].first << " dark"

        assert_equal({"tags" => ["light"]}, StringDefaultRequest.process({}, version: "2025-06"))
      end
    end

    def test_does_not_insert_defaults_when_turned_off
      with_configuration(insert_property_defaults: false) do
        assert_equal({"items" => [{"name" => "a"}]}, Request.process({"items" => [{"name" => "a"}]}, version: "2025-06"))
      end
    end
  end
end

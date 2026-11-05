# frozen_string_literal: true

require "test_helper"

module Verquest
  class LocationTest < Minitest::Test
    def test_location_defaults_to_body
      assert_equal :body, Class.new(Verquest::Base).location
    end

    def test_location_is_inherited
      parent = Class.new(Verquest::Base) { location :query }

      assert_equal :query, Class.new(parent).location
    end

    def test_invalid_location
      error = assert_raises(ArgumentError) { Class.new(Verquest::Base) { location :header } }

      assert_equal "Location must be one of body, query, path", error.message
    end

    def test_location_after_version
      error = assert_raises(ArgumentError) do
        Class.new(Verquest::Base) do
          version("2025-06") { field :page, type: :integer }
          location :query
        end
      end

      assert_equal "Location must be set before the first version", error.message
    end

    def test_location_after_description
      klass = Class.new(Verquest::Base) do
        description "List"
        location :query
      end

      assert_equal :query, klass.location
    end

    def test_to_parameters_on_body_class
      klass = Class.new(Verquest::Base) { version("2025-06") { field :page, type: :integer } }

      error = assert_raises(ArgumentError) { klass.to_parameters(version: "2025-06") }

      assert_match(/has no parameters \(location :body\)/, error.message)
    end

    def test_body_class_does_not_coerce
      klass = Class.new(Verquest::Base) { version("2025-06") { field :page, type: :integer } }

      assert_raises(InvalidParamsError) { klass.process({"page" => "1"}, version: "2025-06") }
    end

    def test_query_class_coerces
      klass = Class.new(Verquest::Base) do
        location :query
        version("2025-06") { field :page, type: :integer }
      end

      assert_equal({"page" => 1}, klass.process({"page" => "1"}, version: "2025-06"))
    end

    def test_path_class_coerces
      klass = Class.new(Verquest::Base) do
        location :path
        version("2025-06") { field :id, type: :integer, required: true }
      end

      assert_equal({"id" => 1}, klass.process({"id" => "1"}, version: "2025-06"))
    end
  end
end

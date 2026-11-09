# frozen_string_literal: true

require "test_helper"

module Verquest
  class PropertyNamesTest < Minitest::Test
    include ConfigurationTestHelper

    QUERY = Class.new(Verquest::Base) do
      location :query

      version "2025-06" do
        field :page, type: :integer
        enum :sort_direction, values: %w[ASC DESC]
        filter(:status, type: :string) { |target, _value| target }
        object :created do
          field :after, type: :string, format: "date-time"
        end
      end

      version "2025-08", exclude_properties: %i[sort_direction] do
        field :limit, type: :integer
      end
    end

    BODY = Class.new(Verquest::Base) do
      version("2025-06") { field :name, type: :string, map: "full_name" }
    end

    def test_root_property_names_in_declaration_order
      assert_equal %w[page sort_direction status created], QUERY.property_names(version: "2025-06")
    end

    def test_inherited_and_excluded_properties
      assert_equal %w[page status created limit], QUERY.property_names(version: "2025-08")
    end

    def test_a_body_request_names_its_external_keys
      assert_equal %w[name], BODY.property_names(version: "2025-06")
    end

    def test_the_current_version_is_the_default
      with_configuration(current_version: -> { "2025-08" }) do
        assert_equal %w[page status created limit], QUERY.property_names
      end
    end
  end
end

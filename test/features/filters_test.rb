# frozen_string_literal: true

require "test_helper"

module Verquest
  class FiltersTest < Minitest::Test
    ITEMS = [
      {status: "open", site: "a", name: "First"},
      {status: "won", site: "b", name: "Second"},
      {status: "lost", site: "a", name: "Third"}
    ].freeze

    class ItemsQuery < Verquest::Base
      location :query

      version "2025-06" do
        field :page, type: :integer
        filter :status, as: :array, type: :string, explode: false do |items, value|
          items.select { |item| value.include?(item[:status]) }
        end
        filter :site, type: :string do |items, value|
          items.select { |item| item[:site] == value }
        end
        filter :kind, as: :enum, values: %w[a b] do |items, _value|
          items
        end
      end

      version "2025-08", exclude_properties: %i[kind] do
        filter :site, type: :string do |items, value|
          items.reject { |item| item[:site] == value }
        end
        filter :name, type: :string do |items, value|
          items.select { |item| item[:name] == value }
        end
      end

      version "2025-10", inherit: "2025-06" do
        exclude_properties :status
        field :site, type: :string
      end
    end

    def test_filter_declares_the_property_with_the_method_as_names
      parameters = ItemsQuery.to_parameters(version: "2025-06").to_h { |parameter| [parameter[:name], parameter[:schema]] }

      assert_equal "array", parameters["status"][:type]
      assert_equal "string", parameters["site"][:type]
      assert_equal %w[a b], parameters["kind"][:enum]
    end

    def test_filter_names_follow_declaration_and_inheritance
      assert_equal %w[status site kind], ItemsQuery.filter_names(version: "2025-06")
      assert_equal %w[status site name], ItemsQuery.filter_names(version: "2025-08")
      assert_equal %w[kind], ItemsQuery.filter_names(version: "2025-10")
    end

    def test_apply_filters_runs_the_blocks_in_declaration_order
      params = ItemsQuery.process({"status" => "open,lost", "site" => "a"}, version: "2025-06")

      assert_equal %w[First Third], names(ItemsQuery.apply_filters(ITEMS, params, version: "2025-06"))
    end

    def test_apply_filters_skips_nil_and_empty_values
      assert_equal ITEMS, ItemsQuery.apply_filters(ITEMS, {"status" => [], "site" => nil, "name" => ""}, version: "2025-08")
    end

    def test_a_redeclared_filter_replaces_the_block_for_its_version
      assert_equal %w[Second], names(ItemsQuery.apply_filters(ITEMS, {"site" => "a"}, version: "2025-08"))
      assert_equal %w[First Third], names(ItemsQuery.apply_filters(ITEMS, {"site" => "a"}, version: "2025-06"))
    end

    def test_a_plain_property_over_an_inherited_filter_stops_filtering
      assert_equal ITEMS, ItemsQuery.apply_filters(ITEMS, {"site" => "a"}, version: "2025-10")
    end

    def test_apply_filters_resolves_the_current_version
      Verquest.configuration.stubs(:current_version).returns(-> { "2025-08" })

      assert_equal %w[First], names(ItemsQuery.apply_filters(ITEMS, {"name" => "First"}))
    end

    def test_filter_needs_a_block
      error = assert_raises(DefinitionError) { query { filter :status, type: :string } }

      assert_equal "Filter 'status' in version '2025-06' needs a block that filters the target", error.message
    end

    def test_filter_as_must_declare_a_scalar_or_list_property
      error = assert_raises(DefinitionError) { query { filter(:status, as: :object) { |target, _value| target } } }

      assert_equal "Filter 'status' in version '2025-06' can't be declared as: :object, only as :field, :array or :enum", error.message
    end

    def test_filter_cant_be_mapped
      error = assert_raises(DefinitionError) { query { filter(:status, type: :string, map: "/state") { |target, _value| target } } }

      assert_equal "Filter 'status' in version '2025-06' can't use map:, apply_filters reads the value by its name", error.message
    end

    def test_filter_must_be_at_the_root_of_a_version
      error = assert_raises(DefinitionError) do
        query { object(:created) { filter(:after, type: :string) { |target, _value| target } } }
      end

      assert_equal "Filter 'after' in version '2025-06' must be declared at the root of the version, outside object, collection, one_of and conditions", error.message
    end

    def test_filter_cant_be_declared_in_a_condition
      error = assert_raises(DefinitionError) do
        query do
          field :kind, type: :string
          condition(:dated) do
            given { present :kind }
            then_apply { filter(:after, type: :string) { |target, _value| target } }
          end
        end
      end

      assert_match(/\AFilter 'after' in version '2025-06' must be declared at the root/, error.message)
    end

    private

    def names(items) = items.map { |item| item[:name] }

    def query(&block)
      Class.new(Verquest::Base) do
        location :query
        version("2025-06", &block)
      end
    end
  end
end

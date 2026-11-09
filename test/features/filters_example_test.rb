# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/deals_index_query"

module Verquest
  class FiltersExampleTest < Minitest::Test
    DEALS = [
      {name: "First", status: "open", site_id: "site_1"},
      {name: "Second", status: "won", site_id: "site_2"},
      {name: "Third", status: "lost", site_id: "site_1"}
    ].freeze

    def test_filter_names
      assert_equal %w[status], DealsIndexQuery.filter_names(version: "2025-06")
      assert_equal %w[status site_id], DealsIndexQuery.filter_names(version: "2025-08")
    end

    def test_process_and_apply_filters
      params = DealsIndexQuery.process({"page" => "2", "status" => "open,lost", "site_id" => "site_1"}, version: "2025-08")

      assert_equal({"page" => 2, "sort_direction" => "DESC", "status" => %w[open lost], "site_id" => "site_1"}, params)
      assert_equal %w[First Third], names(DealsIndexQuery.apply_filters(DEALS, params, version: "2025-08"))
    end

    def test_a_filter_from_a_newer_version_is_dropped_by_default
      params = DealsIndexQuery.process({"site_id" => "site_2"}, version: "2025-06")

      assert_equal DEALS, DealsIndexQuery.apply_filters(DEALS, params, version: "2025-06")
    end

    def test_a_filter_from_a_newer_version_is_rejected_with_reject_other_version_keys
      error = assert_raises(InvalidParamsError) do
        DealsIndexQuery.process({"site_id" => "site_2", "utm_source" => "mail"}, version: "2025-06", reject_other_version_keys: true)
      end

      assert_equal [{pointer: "/site_id", type: "other_version", message: "`site_id` isn't available in version 2025-06", details: nil}], error.errors
    end

    private

    def names(deals) = deals.map { |deal| deal[:name] }
  end
end

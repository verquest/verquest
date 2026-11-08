# frozen_string_literal: true

require "test_helper"

module Verquest
  class OtherVersionKeysTest < Minitest::Test
    include ConfigurationTestHelper

    class OrdersRequest < Verquest::Base
      version "2025-06" do
        field :name, type: :string
        field :email, type: :string
      end

      version "2025-08", exclude_properties: %i[email] do
        field :site_id, type: :string
      end
    end

    class OrdersQuery < Verquest::Base
      location :query

      version("2025-06") { field :page, type: :integer }
      version("2025-08") { field :site_id, type: :string }
    end

    def test_a_key_added_in_a_newer_version_is_rejected
      error = assert_raises(InvalidParamsError) do
        OrdersRequest.process({"name" => "A", "site_id" => "site_1"}, version: "2025-06", reject_other_version_keys: true)
      end

      assert_equal [{pointer: "/site_id", type: "other_version", message: "`site_id` isn't available in version 2025-06", details: nil}], error.errors
    end

    def test_a_key_removed_in_a_newer_version_is_rejected
      error = assert_raises(InvalidParamsError) do
        OrdersRequest.process({"email" => "a@b.com"}, version: "2025-08", reject_other_version_keys: true)
      end

      assert_equal ["/email"], error.errors.map { |e| e[:pointer] }
    end

    def test_a_key_no_version_declares_is_left_to_remove_extra_root_keys
      assert_equal({"name" => "A"}, OrdersRequest.process({"name" => "A", "cache_buster" => "1"}, version: "2025-06", reject_other_version_keys: true))
    end

    def test_the_check_is_off_by_default
      assert_equal({"name" => "A"}, OrdersRequest.process({"name" => "A", "site_id" => "site_1"}, version: "2025-06"))
    end

    def test_the_configuration_turns_the_check_on
      with_configuration(reject_other_version_keys: true) do
        assert_raises(InvalidParamsError) { OrdersRequest.process({"site_id" => "site_1"}, version: "2025-06") }
      end
    end

    def test_the_errors_are_a_failed_result_with_result_handling
      with_configuration(validation_error_handling: :result) do
        result = OrdersRequest.process({"site_id" => "site_1"}, version: "2025-06", reject_other_version_keys: true)

        assert_predicate result, :failure?
        assert_equal ["/site_id"], result.errors.map { |e| e[:pointer] }
      end
    end

    def test_query_keys_are_checked_too
      assert_raises(InvalidParamsError) { OrdersQuery.process({"site_id" => "site_1"}, version: "2025-06", reject_other_version_keys: true) }
    end

    def test_validate_false_skips_the_check
      params = OrdersRequest.process({"name" => "A", "site_id" => "site_1"}, version: "2025-06", validate: false, reject_other_version_keys: true)

      assert_equal({"name" => "A"}, params)
    end

    def test_a_version_declared_after_the_first_check_is_included
      request = Class.new(Verquest::Base) { version("2025-06") { field :name, type: :string } }
      request.process({"name" => "A"}, version: "2025-06", reject_other_version_keys: true)
      request.class_eval { version("2025-08") { field :site_id, type: :string } }

      assert_raises(InvalidParamsError) { request.process({"site_id" => "site_1"}, version: "2025-06", reject_other_version_keys: true) }
    end
  end
end

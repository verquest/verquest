# frozen_string_literal: true

require "test_helper"

module Verquest
  class LenientQueryParamsTest < Minitest::Test
    include ConfigurationTestHelper

    QUERY = Class.new(Verquest::Base) do
      location :query

      version "2025-06" do
        field :page, type: :integer, minimum: 1
        field :limit, type: :integer, minimum: 1, maximum: 100
        enum :sort_direction, values: %w[ASC DESC]
        field :note, type: :string, nullable: true
        field :search, type: :string
        field :created_after, type: :string, format: "date-time"
        filter :status, as: :array, type: :string, explode: false, item_schema_options: {enum: %w[open won]} do |target, _value|
          target
        end
        filter :site_id, type: :string, pattern: "^site_" do |target, _value|
          target
        end
      end
    end

    REQUIRED = Class.new(Verquest::Base) do
      location :query

      version "2025-06" do
        field :limit, type: :integer, minimum: 1, required: true
        enum :kind, values: %w[unit site], required: true
      end
    end

    BODY = Class.new(Verquest::Base) do
      version("2025-06") { field :page, type: :integer }
    end

    # Processes params for a request of version with lenient_through "2025-06", returning the params and corrections
    def lenient_process(params, version: "2025-06", query: QUERY, **options)
      corrections = []
      result = with_configuration(lenient_through: "2025-06") do
        query.process(params, version:, **options) { |correction| corrections << correction }
      end
      [result, corrections]
    end

    def correction(path, rule, from, to)
      Correction.new(path:, rule:, from:, to:)
    end

    def test_blank_values_are_removed
      result, corrections = lenient_process({"page" => "", "site_id" => " "})

      assert_empty result
      assert_equal [correction("/page", :blank, "", nil), correction("/site_id", :blank, " ", nil)], corrections
    end

    # Strict requests accept "" for these, so leniency leaves it alone and reports nothing
    def test_blank_values_strict_requests_accept_are_kept
      result, corrections = lenient_process({"note" => "", "search" => "", "status" => ""})

      assert_equal({"note" => "", "search" => "", "status" => []}, result)
      assert_empty corrections
    end

    def test_a_request_after_lenient_through_is_strict
      assert_raises(InvalidParamsError) { lenient_process({"page" => ""}, version: "2025-12") }
    end

    def test_requests_are_strict_without_lenient_through
      assert_raises(InvalidParamsError) { QUERY.process({"page" => ""}, version: "2025-06") }
    end

    def test_lenient_overrides_the_configuration
      assert_raises(InvalidParamsError) { lenient_process({"page" => ""}, lenient: false) }
      assert_empty QUERY.process({"page" => ""}, version: "2025-06", lenient: true)
    end

    # Stora passes no version: the requested version comes from current_version
    def test_the_current_version_decides_leniency
      with_configuration(current_version: -> { "2025-06" }, lenient_through: "2025-06") do
        assert_empty QUERY.process({"page" => ""})
      end
      with_configuration(current_version: -> { "2025-12" }, lenient_through: "2025-06") do
        assert_raises(InvalidParamsError) { QUERY.process({"page" => ""}) }
      end
    end

    # Version names after the dated ones, such as "preview", sort last
    def test_lenient_through_a_named_version
      with_configuration(lenient_through: "preview") do
        assert_empty QUERY.process({"page" => ""}, version: "2025-06")
      end
    end

    def test_path_requests_are_lenient
      path = Class.new(Verquest::Base) do
        location :path
        version("2025-06") { enum :kind, values: %w[unit site], required: true }
      end

      result, corrections = lenient_process({"kind" => "Unit"}, query: path)

      assert_equal({"kind" => "unit"}, result)
      assert_equal [correction("/kind", :enum_case, "Unit", "unit")], corrections
    end

    def test_body_requests_are_strict
      assert_raises(InvalidParamsError) { lenient_process({"page" => ""}, query: BODY) }
    end

    def test_corrections_are_yielded_with_result_handling
      result, corrections = with_configuration(validation_error_handling: :result) { lenient_process({"page" => ""}) }

      assert_predicate result, :success?
      assert_equal [correction("/page", :blank, "", nil)], corrections
    end

    def test_enum_values_match_case_insensitively
      result, corrections = lenient_process({"sort_direction" => "desc", "status" => "Open,won"})

      assert_equal({"sort_direction" => "DESC", "status" => %w[open won]}, result)
      assert_equal [correction("/sort_direction", :enum_case, "desc", "DESC"), correction("/status/0", :enum_case, "Open", "open")], corrections
    end

    def test_an_ambiguous_case_match_is_not_corrected
      query = Class.new(Verquest::Base) do
        location :query
        version("2025-06") do
          filter(:size, as: :enum, values: %w[ab AB]) { |target, _value| target }
        end
      end

      assert_raises(InvalidParamsError) { lenient_process({"size" => "Ab"}, query:) }
    end

    def test_values_above_the_maximum_are_capped
      result, corrections = lenient_process({"limit" => "200"})

      assert_equal({"limit" => 100}, result)
      assert_equal [correction("/limit", :maximum, "200", 100)], corrections
    end

    def test_values_within_the_maximum_are_not_corrected
      result, corrections = lenient_process({"limit" => "100"})

      assert_equal({"limit" => 100}, result)
      assert_empty corrections
    end

    def test_date_times_get_an_offset
      {
        "2025-01-12T15:30:00" => "2025-01-12T15:30:00Z",
        "2025-01-12T15:30:00.5" => "2025-01-12T15:30:00.5Z",
        "2025-01-12T15:30:00+0100" => "2025-01-12T15:30:00+01:00",
        "2025-01-12T15:30:00-0530" => "2025-01-12T15:30:00-05:30"
      }.each do |from, to|
        result, corrections = lenient_process({"created_after" => from})

        assert_equal({"created_after" => to}, result)
        assert_equal [correction("/created_after", :datetime_offset, from, to)], corrections
      end
    end

    # A corrected value is echoed to clients, so a long fraction is left for validation
    def test_date_times_with_a_long_fraction_are_not_corrected
      result, corrections = lenient_process({"created_after" => "2025-01-12T15:30:00.1234567890"})

      assert_empty result
      assert_equal [correction("/created_after", :invalid, "2025-01-12T15:30:00.1234567890", nil)], corrections
    end

    def test_date_times_with_an_offset_are_not_corrected
      %w[2025-01-12T15:30:00Z 2025-01-12T15:30:00+01:00].each do |value|
        result, corrections = lenient_process({"created_after" => value})

        assert_equal({"created_after" => value}, result)
        assert_empty corrections
      end
    end

    def test_invalid_values_of_other_properties_are_removed
      result, corrections = lenient_process({"page" => "0", "limit" => "abc", "sort_direction" => "up", "site_id" => "site_1"})

      assert_equal({"site_id" => "site_1"}, result)
      assert_equal [correction("/limit", :invalid, "abc", nil), correction("/page", :invalid, "0", nil), correction("/sort_direction", :invalid, "up", nil)],
        corrections.sort_by(&:path)
    end

    def test_a_removed_invalid_value_gets_the_default
      query = Class.new(Verquest::Base) do
        location :query
        version("2025-06") { field :page, type: :integer, minimum: 1, default: 1 }
      end

      result, corrections = lenient_process({"page" => "0"}, query:)

      assert_equal({"page" => 1}, result)
      assert_equal [correction("/page", :invalid, "0", nil)], corrections
    end

    def test_an_object_for_a_scalar_is_removed
      result, corrections = lenient_process({"page" => {"size" => "50"}})

      assert_empty result
      assert_equal [correction("/page", :invalid, {"size" => "50"}, nil)], corrections
    end

    # A value gets one correction: the date-time got an offset but is still invalid, so it's only removed
    def test_a_corrected_value_that_is_still_invalid_is_only_removed
      result, corrections = lenient_process({"created_after" => "2025-13-45T00:00:00"})

      assert_empty result
      assert_equal [correction("/created_after", :invalid, "2025-13-45T00:00:00", nil)], corrections
    end

    # Removing a filter would silently return an unfiltered list
    def test_invalid_filter_values_are_rejected
      corrections = []
      error = assert_raises(InvalidParamsError) do
        with_configuration(lenient_through: "2025-06") do
          QUERY.process({"status" => "closed", "site_id" => "x", "page" => "0"}, version: "2025-06") { |correction| corrections << correction }
        end
      end

      assert_equal %w[/site_id /status/0], error.errors.map { |detail| detail[:pointer] }.sort
      assert_equal [correction("/page", :invalid, "0", nil)], corrections
    end

    # Unknown keys are the caller's choice (remove_extra_root_keys), not something leniency removes
    def test_unknown_keys_are_not_removed
      assert_raises(InvalidParamsError) { lenient_process({"extra" => "1"}, remove_extra_root_keys: false) }
    end

    def test_lenient_through_defaults_to_nil
      assert_nil Configuration.new.lenient_through
    end

    def test_correction_names_its_root_property
      assert_equal "page", Correction.new(path: "/page", rule: :blank, from: "", to: nil).name
    end

    # Removing a required property only turns its error into "missing required properties"
    def test_an_invalid_required_value_keeps_its_error
      corrections = []
      error = assert_raises(InvalidParamsError) do
        with_configuration(lenient_through: "2025-06") do
          REQUIRED.process({"limit" => "0", "kind" => "unit"}, version: "2025-06") { |correction| corrections << correction }
        end
      end

      assert_equal ["/limit"], error.errors.map { |detail| detail[:pointer] }
      assert_empty corrections
    end

    def test_a_blank_required_value_keeps_its_error
      corrections = []
      error = assert_raises(InvalidParamsError) do
        with_configuration(lenient_through: "2025-06") do
          REQUIRED.process({"limit" => "", "kind" => "unit"}, version: "2025-06") { |correction| corrections << correction }
        end
      end

      assert_equal ["/limit"], error.errors.map { |detail| detail[:pointer] }
      assert_empty corrections
    end

    def test_a_required_value_is_still_corrected
      result, corrections = lenient_process({"limit" => "5", "kind" => "Unit"}, query: REQUIRED)

      assert_equal({"limit" => 5, "kind" => "unit"}, result)
      assert_equal [correction("/kind", :enum_case, "Unit", "unit")], corrections
    end

    def test_an_invalid_path_id_keeps_its_error
      path = Class.new(Verquest::Base) do
        location :path
        version("2025-06") { field :id, type: :string, pattern: "^con_", required: true }
      end

      error = assert_raises(InvalidParamsError) { lenient_process({"id" => "387979"}, query: path) }

      assert_equal ["/id"], error.errors.map { |detail| detail[:pointer] }
    end

    # Like a filter: the correction is reported, then the value fails with its own error
    def test_a_corrected_required_value_that_is_still_invalid_keeps_its_error
      corrections = []
      query = Class.new(Verquest::Base) do
        location :path
        version("2025-06") { field :at, type: :string, format: "date-time", required: true }
      end
      error = assert_raises(InvalidParamsError) do
        with_configuration(lenient_through: "2025-06") do
          query.process({"at" => "2025-13-45T00:00:00"}, version: "2025-06") { |correction| corrections << correction }
        end
      end

      assert_equal ["/at"], error.errors.map { |detail| detail[:pointer] }
      assert_equal [correction("/at", :datetime_offset, "2025-13-45T00:00:00", "2025-13-45T00:00:00Z")], corrections
    end

    def test_a_dependent_required_value_keeps_its_error
      query = Class.new(Verquest::Base) do
        location :query

        version "2025-06" do
          field :page, type: :integer, required: [:per]
          field :per, type: :integer, minimum: 1
        end
      end

      corrections = []
      error = assert_raises(InvalidParamsError) do
        with_configuration(lenient_through: "2025-06") do
          query.process({"page" => "1", "per" => "0"}, version: "2025-06") { |correction| corrections << correction }
        end
      end

      assert_equal ["/per"], error.errors.map { |detail| detail[:pointer] }
      assert_empty corrections
    end

    def test_an_invalid_value_a_condition_requires_keeps_its_error
      query = Class.new(Verquest::Base) do
        location :query

        version "2025-06" do
          field :kind, type: :string
          depends_on(:kind) { field :per, type: :integer, minimum: 1, required: true }
        end
      end
      corrections = []
      error = assert_raises(InvalidParamsError) do
        with_configuration(lenient_through: "2025-06") do
          query.process({"kind" => "x", "per" => "0"}, version: "2025-06") { |correction| corrections << correction }
        end
      end

      assert_equal ["/per"], error.errors.map { |detail| detail[:pointer] }
      assert_empty corrections
    end

    # Several conditions go into allOf
    def test_a_blank_value_a_condition_requires_keeps_its_error
      query = Class.new(Verquest::Base) do
        location :query

        version "2025-06" do
          field :kind, type: :string
          field :mode, type: :string
          depends_on(:mode) { present :kind }
          depends_on(:kind) { field :per, type: :integer, minimum: 1, required: true }
        end
      end
      corrections = []
      error = assert_raises(InvalidParamsError) do
        with_configuration(lenient_through: "2025-06") do
          query.process({"kind" => "x", "per" => ""}, version: "2025-06") { |correction| corrections << correction }
        end
      end

      assert_equal ["/per"], error.errors.map { |detail| detail[:pointer] }
      assert_empty corrections
    end

    # A name any alternative of an anyOf requires is kept
    def test_an_invalid_value_an_any_rule_requires_keeps_its_error
      query = Class.new(Verquest::Base) do
        location :query

        version "2025-06" do
          field :kind, type: :string
          field :a, type: :integer, minimum: 1
          field :b, type: :integer
          condition(:a_or_b) do
            given { present :kind }
            then_apply do
              any do
                present :a
                present :b
              end
            end
          end
        end
      end
      corrections = []
      error = assert_raises(InvalidParamsError) do
        with_configuration(lenient_through: "2025-06") do
          query.process({"kind" => "x", "a" => "0"}, version: "2025-06") { |correction| corrections << correction }
        end
      end

      assert_equal ["/a"], error.errors.map { |detail| detail[:pointer] }
      assert_empty corrections
    end

    def test_corrected_date_times_use_t
      {
        "2025-01-12 15:30:00" => "2025-01-12T15:30:00Z",
        "2025-01-12t15:30:00+0100" => "2025-01-12T15:30:00+01:00"
      }.each do |from, to|
        result, corrections = lenient_process({"created_after" => from})

        assert_equal({"created_after" => to}, result)
        assert_equal [correction("/created_after", :datetime_offset, from, to)], corrections
      end
    end

    # Strict requests accept a space when the offset is there, so it's not corrected
    def test_a_space_with_an_offset_is_not_corrected
      result, corrections = lenient_process({"created_after" => "2025-01-12 15:30:00Z"})

      assert_equal({"created_after" => "2025-01-12 15:30:00Z"}, result)
      assert_empty corrections
    end

    def test_a_correction_points_at_the_corrected_value
      query = Class.new(Verquest::Base) do
        location :query

        version "2025-06" do
          object(:created) { field :gte, type: :string, format: "date-time" }
          filter(:status, as: :array, type: :string, explode: false, item_schema_options: {enum: %w[open won]}) { |target, _value| target }
        end
      end

      result, corrections = lenient_process({"created" => {"gte" => "2025-01-12T15:30:00"}, "status" => "open,Won"}, query:)

      assert_equal({"created" => {"gte" => "2025-01-12T15:30:00Z"}, "status" => %w[open won]}, result)
      assert_equal [correction("/created/gte", :datetime_offset, "2025-01-12T15:30:00", "2025-01-12T15:30:00Z"), correction("/status/1", :enum_case, "Won", "won")], corrections
      assert_equal %w[created status], corrections.map(&:name)
    end

    def test_a_missing_required_property_is_reported
      error = assert_raises(InvalidParamsError) { lenient_process({"kind" => "unit"}, query: REQUIRED) }

      assert_equal [""], error.errors.map { |detail| detail[:pointer] }
    end

    # The validation error's pointer is escaped like the correction's
    def test_an_invalid_property_with_an_escaped_name_is_removed
      query = Class.new(Verquest::Base) do
        location :query
        version("2025-06") { field :"a/b~c", type: :integer, minimum: 1 }
      end

      result, corrections = lenient_process({"a/b~c" => "0"}, query:)

      assert_empty result
      assert_equal [correction("/a~1b~0c", :invalid, "0", nil)], corrections
      assert_equal ["a/b~c"], corrections.map(&:name)
    end
  end
end

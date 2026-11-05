# frozen_string_literal: true

require "test_helper"

module Verquest
  class SupportedVersionsTest < Minitest::Test
    include ConfigurationTestHelper

    # Orders "v9" before "v10", unlike string comparison
    NUMERIC = lambda do |requested, versions|
      number = ->(name) { name.delete_prefix("v").to_i }
      versions.select { |name| number.call(name) <= number.call(requested) }.max_by(&number)
    end

    def test_covers_versions_between_min_and_max
      range = SupportedVersions.new(min: "2025-09", max: "2026-03")

      assert range.covers?("2025-09")
      assert range.covers?("2026-03")
      refute range.covers?("preview")
    end

    def test_bounds_are_optional
      refute SupportedVersions.new(min: "2025-09", max: nil).covers?("2025-06")
      assert SupportedVersions.new(min: "2025-09", max: nil).covers?("preview")
      assert SupportedVersions.new(min: nil, max: "2025-09").covers?("2025-06")
    end

    def test_min_after_max_raises
      error = assert_raises(DefinitionError) { SupportedVersions.new(min: "preview", max: "2025-09") }

      assert_equal "supported_versions min: preview is after max: 2025-09", error.message
    end

    def test_check_raises_when_max_is_before_every_declared_version
      error = assert_raises(DefinitionError) { SupportedVersions.new(min: nil, max: "2025-06").check!(%w[2025-09 preview], "OverlockRequest") }

      assert_equal "OverlockRequest: supported_versions max: 2025-06 is before every declared version (2025-09, preview)", error.message
      assert_nil SupportedVersions.new(min: "2025-06", max: "2025-09").check!(%w[2025-09 preview], "OverlockRequest")
    end

    def test_check_allows_min_after_every_declared_version
      assert_nil SupportedVersions.new(min: "preview", max: nil).check!(%w[2025-09], "OverlockRequest")
      assert_nil SupportedVersions.new(min: nil, max: "2025-06").check!([], "OverlockRequest")
    end

    def test_order_follows_the_configured_resolver
      assert_raises(DefinitionError) { SupportedVersions.new(min: "v9", max: "v10") }

      with_configuration(version_resolver: NUMERIC) do
        range = SupportedVersions.new(min: "v9", max: "v10")

        assert range.covers?("v10")
        refute range.covers?("v11")
      end
    end

    def test_to_s
      assert_equal "min: 2025-09, max: none", SupportedVersions.new(min: "2025-09", max: nil).to_s
      assert_equal "min: first declared, max: 2026-03", SupportedVersions.new(min: nil, max: "2026-03").to_s
    end
  end
end

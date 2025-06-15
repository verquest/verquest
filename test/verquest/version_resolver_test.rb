# frozen_string_literal: true

require "test_helper"

module Verquest
  class VersionResolverTest < Minitest::Test
    def test_exact_match
      version = "2025-07"
      versions = %w[2025-06 2025-07 2025-08]

      resolved_version = VersionResolver.call(version, versions)

      assert_equal "2025-07", resolved_version
    end

    def test_not_exact_resolve_first_previous
      version = "2025-10"
      versions = %w[2025-06 2025-08 2025-12]

      resolved_version = VersionResolver.call(version, versions)

      assert_equal "2025-08", resolved_version
    end

    def test_exact_match_numbered
      version = "v1"
      versions = %w[v1 v3]

      resolved_version = VersionResolver.call(version, versions)

      assert_equal "v1", resolved_version
    end

    def test_not_exact_resolve_first_previous_numbered
      version = "v4"
      versions = %w[v1 v3 v5]

      resolved_version = VersionResolver.call(version, versions)

      assert_equal "v3", resolved_version
    end
  end
end

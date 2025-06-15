# frozen_string_literal: true

module Verquest
  # Resolves requested version identifiers to actual version objects
  #
  # The VersionResolver handles version resolution logic, finding the appropriate
  # version to use based on a requested version identifier. It implements a "downgrading"
  # strategy - when an exact version match isn't found, it returns the closest earlier version.
  #
  # @example Resolving a version
  #   versions = ["2025-01", "2025-06", "2026-01"]
  #
  #   # Exact match
  #   Verquest::VersionResolver.call("2025-06", versions) # => "2025-06"
  #
  #   # Between versions - returns previous version
  #   Verquest::VersionResolver.call("2025-04", versions) # => "2025-01"
  #
  #   # After latest version - returns latest
  #   Verquest::VersionResolver.call("2026-06", versions) # => "2026-01"
  class VersionResolver
    # Resolves a requested version to the appropriate available version
    #
    # This method implements the version resolution strategy:
    # - If an exact match is found, that version is returned
    # - If the requested version is between two available versions, the earlier one is returned
    # - If the requested version is after all available versions, the latest version is returned
    #
    # @param requested_version [String] The version identifier requested
    # @param versions [Array<String>] List of available version identifiers, sorted by age (oldest first)
    # @return [String, nil] The resolved version, or nil if no versions available
    def self.call(requested_version, versions)
      versions.each_with_index do |version, index|
        return version if version == requested_version

        if requested_version > version && ((versions[index + 1] && requested_version < versions[index + 1]) || !versions[index + 1])
          return version
        end
      end
    end
  end
end

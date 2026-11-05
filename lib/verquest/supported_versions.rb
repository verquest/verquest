# frozen_string_literal: true

module Verquest
  # Inclusive range of versions a request serves, declared with `supported_versions`
  #
  # Versions are compared with the configured version resolver, so the range uses the same
  # order as version resolution. With the default resolver that is string order, where
  # "preview" sorts after dated versions.
  #
  # @example
  #   range = Verquest::SupportedVersions.new(min: "2025-09", max: "2026-03")
  #   range.covers?("2025-12") # => true
  #   range.covers?("2026-06") # => false
  class SupportedVersions
    # @return [String, nil] The first supported version, nil to start at the first declared version
    attr_reader :min

    # @return [String, nil] The last supported version, nil for no upper bound
    attr_reader :max

    # Returns whether one version sorts at or before another
    #
    # The resolver picks `earlier` for a request of `later` only when `earlier` comes at or before it.
    #
    # @param earlier [String] The version expected first
    # @param later [String] The version expected second
    # @return [Boolean] true when earlier sorts at or before later
    def self.at_or_before?(earlier, later)
      Verquest.configuration.version_resolver.call(later, [earlier]) == earlier
    end

    # @param min [String, nil] The first supported version (inclusive)
    # @param max [String, nil] The last supported version (inclusive)
    # @raise [Verquest::DefinitionError] If min sorts after max
    def initialize(min:, max:)
      @min = min&.to_s
      @max = max&.to_s
      raise DefinitionError, "supported_versions min: #{@min} is after max: #{@max}" if @min && @max && !self.class.at_or_before?(@min, @max)

      freeze
    end

    # Returns whether the range includes a version
    #
    # Without min, earlier versions are left to the resolver, which finds nothing before the first declared version.
    #
    # @param version [String] The version name
    # @return [Boolean] true when the version is within the range
    def covers?(version)
      (min.nil? || self.class.at_or_before?(min, version)) && (max.nil? || self.class.at_or_before?(version, max))
    end

    # Raises when max sorts before every declared version, so no request could resolve
    #
    # Only max is checked: declared blocks don't have to be inside the range, so
    # `min: "preview"` with a single `version "2025-09"` block serves "preview" from 2025-09.
    #
    # @param declared [Array<String>] The declared version names
    # @param owner [String] The class name, for the error message
    # @return [void]
    # @raise [Verquest::DefinitionError] If max sorts before every declared version
    def check!(declared, owner)
      return if max.nil? || declared.empty? || declared.any? { |version| self.class.at_or_before?(version, max) }

      raise DefinitionError, "#{owner}: supported_versions max: #{max} is before every declared version (#{declared.join(", ")})"
    end

    # @return [String] The range for error messages, like "min: 2025-09, max: none"
    def to_s
      "min: #{min || "first declared"}, max: #{max || "none"}"
    end
  end
end

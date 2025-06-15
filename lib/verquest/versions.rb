# frozen_string_literal: true

module Verquest
  # Container for managing multiple API versions
  #
  # The Versions class stores and provides access to all available versions of an
  # API request schema. It handles adding new versions and resolving version identifiers
  # to specific Version objects based on the configured version resolution strategy.
  #
  # @example Adding and resolving versions
  #   versions = Verquest::Versions.new
  #
  #   # Add versions
  #   versions.add(Verquest::Version.new(name: "2022-01"))
  #   versions.add(Verquest::Version.new(name: "2023-01"))
  #
  #   # Resolve a version
  #   version = versions.resolve("2022-06") # Returns "2022-01" version based on resolver
  class Versions
    # @!attribute [rw] description
    #   @return [String] Default description for versions that don't specify one
    #
    # @!attribute [rw] schema_options
    #   @return [Hash] Default schema options for versions that don't specify any
    attr_accessor :description, :schema_options

    # Initialize a new Versions container
    #
    # @return [Versions] A new Versions instance
    def initialize
      @versions = {}
      @schema_options = {}
    end

    # Add a version to the container
    #
    # @param version [Verquest::Version] The version to add
    # @return [Verquest::Version] The added version
    # @raise [ArgumentError] If the provided object is not a Version instance
    def add(version)
      raise ArgumentError, "Expected a Verquest::Version instance" unless version.is_a?(Verquest::Version)

      versions[version.name] = version
    end

    # Resolve a version identifier to a specific Version object
    #
    # Uses the configured version resolver to determine which version to use
    # based on the requested version identifier.
    #
    # @param version_name [String] The version identifier to resolve
    # @return [Verquest::Version] The resolved Version object
    def resolve(version_name)
      resolved_version_name = Verquest.configuration.version_resolver.call(version_name, versions.keys.sort)

      versions[resolved_version_name] || raise(Verquest::VersionNotFoundError, "Version '#{version_name}' not found")
    end

    private

    # @!attribute [r] versions
    #   @return [Hash<String, Verquest::Version>] The versions stored in this container
    attr_reader :versions
  end
end

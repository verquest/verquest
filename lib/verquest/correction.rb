# frozen_string_literal: true

module Verquest
  # A query or path value a lenient request corrected instead of rejecting
  #
  # @!attribute [r] path
  #   @return [String] JSON pointer of the corrected value, such as "/sort_direction", "/status/0" or
  #     "/created/gte"; an :invalid correction points at the removed root property
  # @!attribute [r] rule
  #   @return [Symbol] :blank, :enum_case, :maximum, :datetime_offset or :invalid
  # @!attribute [r] from
  #   @return [Object] The value the client sent; don't echo it unescaped
  # @!attribute [r] to
  #   @return [Object, nil] The corrected value, nil when the property was removed
  Correction = Data.define(:path, :rule, :from, :to) do
    # Builds a JSON pointer, escaping "~" and "/" in the segments
    #
    # @param segments [Array<String>] The value's path
    # @return [String] The pointer, such as "/status/0"
    def self.pointer(segments) = segments.map { |segment| "/#{segment.gsub(%r{[~/]}, "~" => "~0", "/" => "~1")}" }.join

    # Reads the root property's name from a JSON pointer
    #
    # @param pointer [String] A JSON pointer, such as "/status/0"
    # @return [String, nil] The unescaped first segment, nil for the root pointer ""
    def self.root_name(pointer) = pointer.split("/")[1]&.gsub(/~[01]/, "~0" => "~", "~1" => "/")

    # Builds the correction of a root property
    #
    # @param name [String] The root property's name
    # @param rule [Symbol] The rule that corrected the value
    # @param from [Object] The value the client sent
    # @param to [Object, nil] The corrected value, nil when the property was removed
    # @return [Verquest::Correction]
    def self.for(name, rule:, from:, to:) = new(path: pointer([name]), rule:, from:, to:)

    # @return [String] The root property's name, such as "status" for "/status/0"
    def name = self.class.root_name(path)
  end
end

# frozen_string_literal: true

module Verquest
  module Query
    # Converts query parameters like {Coercer} and corrects values a lenient request tolerates
    #
    # Each correction is reported to the `on_correction` callable as a {Verquest::Correction}.
    # A value gets at most one correction. Values no rule corrects are left for validation.
    #
    # @example
    #   coercer = LenientCoercer.new(schema:, explodes: {}, required: [], on_correction: ->(correction) { log(correction) })
    #   coercer.call({"page" => ""}) # => {}
    class LenientCoercer < Coercer
      # A date-time with at most 9 fraction digits, without an offset or with an offset without a colon
      DATE_TIME_TO_FIX = /\A(?<date>\d{4}-\d{2}-\d{2})[Tt ](?<time>\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?)(?:(?<hours>[+-]\d{2})(?<minutes>\d{2}))?\z/

      # @param schema [Hash] The version's validation schema
      # @param explodes [Hash{Array<String> => Boolean}] The explode value of each array property, by path
      # @param required [Array<String>] Root properties that are never removed (see {Verquest::Version#required_property_names})
      # @param on_correction [#call, nil] Called with each {Verquest::Correction}
      # @param case_insensitive [Set<Array<String>>] Paths of properties matching their enum case-insensitively
      def initialize(schema:, explodes:, required:, on_correction:, case_insensitive: Set.new)
        super(schema:, explodes:, case_insensitive:)
        @required = required
        @on_correction = on_correction
      end

      private

      attr_reader :required, :on_correction

      # Removes blank root values before converting the rest; a required property is kept, so it
      # fails validation with its own error
      #
      # @return [Hash] A copy of the hash without blank root values, with each known property converted
      def coerce_properties(hash, object_schema, path)
        return super unless path.empty?

        properties = object_schema.fetch("properties", {})
        blank = hash.keys.select { |key| removable_blank?(key.to_s, hash[key], properties[key.to_s]) }
        blank.each { |key| correct(path + [key.to_s], :blank, hash[key], nil) }

        super(hash.except(*blank), object_schema, path)
      end

      # @return [Boolean] Whether the value is a blank string of a property that isn't required and rejects it
      def removable_blank?(name, value, property_schema)
        !required.include?(name) && blank_property?(value, property_schema)
      end

      # @return [Boolean] Whether the value is a blank string that the known property rejects
      def blank_property?(value, property_schema)
        !property_schema.nil? && value.is_a?(::String) && value.strip.empty? && !accepts_blank?(property_schema)
      end

      # Strict validation accepts a blank value for an array (it becomes []), a property that
      # accepts null, and a string without constraints, also as an anyOf or oneOf variant,
      # so correcting it would only add noise
      #
      # @return [Boolean] Whether the schema accepts a blank string as it is
      def accepts_blank?(value_schema)
        types = types(value_schema)

        types.include?("array") || types.include?("null") || unconstrained_string?(value_schema, types) ||
          variants(value_schema).any? { |variant| accepts_blank?(variant) }
      end

      # @return [Boolean] Whether the schema is a string without constraints a blank string fails
      def unconstrained_string?(value_schema, types)
        types == ["string"] && (value_schema.keys & %w[enum format pattern minLength const]).empty?
      end

      # @return [Integer, Object] The integer, capped at the schema's maximum, or NO_MATCH
      def coerce_integer(value, value_schema, path)
        capped(super, value, value_schema, path)
      end

      # @return [Numeric, Object] The number, capped at the schema's maximum, or NO_MATCH
      def coerce_number(value, value_schema, path)
        capped(super, value, value_schema, path)
      end

      # @return [Numeric, Object] The schema's maximum when the coerced number is above it, else the coerced value
      def capped(coerced, value, value_schema, path)
        maximum = value_schema["maximum"]
        return coerced if coerced.equal?(NO_MATCH) || maximum.nil? || coerced <= maximum

        correct(path, :maximum, value, maximum)
        maximum
      end

      # Matches an enum value case-insensitively when exactly one declared value matches,
      # and gives a date-time an offset
      #
      # @return [String, Object] The string, the declared value, the date-time with an offset or NO_MATCH
      def coerce_string(value, value_schema, path)
        coerced = super
        return coerced unless value.is_a?(::String)
        return enum_case(value, value_schema, path) if coerced.equal?(NO_MATCH) && value_schema.key?("enum")
        return with_offset(value, path) if value_schema["format"] == "date-time"

        coerced
      end

      # @return [String, Object] The only declared value matching case-insensitively or NO_MATCH
      def enum_case(value, value_schema, path)
        matches = value_schema["enum"].select { |declared| declared.is_a?(::String) && declared.casecmp?(value) }
        return NO_MATCH unless matches.one?

        correct(path, :enum_case, value, matches.first)
        matches.first
      end

      # Adds "Z" to a date-time without an offset, and a colon to a "+HHMM" offset, with "T"
      # between the date and the time
      #
      # @return [String] The date-time, corrected when it matches DATE_TIME_TO_FIX
      def with_offset(value, path)
        match = DATE_TIME_TO_FIX.match(value)
        return value unless match

        corrected = "#{match[:date]}T#{match[:time]}#{offset(match)}"
        correct(path, :datetime_offset, value, corrected)
        corrected
      end

      # @return [String] "+HH:MM" from a "+HHMM" offset, or "Z" without an offset
      def offset(match) = match[:hours] ? "#{match[:hours]}:#{match[:minutes]}" : "Z"

      # Reports a correction at the corrected value's JSON pointer
      #
      # @param path [Array<String>] The value's path, with array indexes
      # @return [void]
      def correct(path, rule, from, to)
        on_correction&.call(Correction.new(path: Correction.pointer(path), rule:, from:, to:))
      end
    end
  end
end

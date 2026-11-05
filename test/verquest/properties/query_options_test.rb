# frozen_string_literal: true

require "test_helper"

module Verquest
  module Properties
    class QueryOptionsTest < Minitest::Test
      EXAMPLES = {single: {value: %w[open]}}.freeze

      class Source < Verquest::Base
        version "2025-06" do
          array :expand, type: :string, explode: false, parameter_examples: {single: {value: %w[contact]}}
          object :filter do
            array :status, type: :string, explode: true
          end
        end
      end

      def test_scalar
        assert_empty Field.new(name: :page, type: :integer).query_options(prefix: [], version: "2025-06")
      end

      def test_scalar_with_examples
        field = Field.new(name: :page, type: :integer)
        field.parameter_examples = EXAMPLES

        assert_equal({%w[page] => {examples: EXAMPLES}}, field.query_options(prefix: [], version: "2025-06"))
      end

      def test_array
        array = Array.new(name: :tags, type: :string, explode: false)

        assert_equal({%w[filter tags] => {explode: false}}, array.query_options(prefix: %w[filter], version: "2025-06"))
      end

      def test_object
        object = Object.new(name: :filter)
        object.parameter_examples = EXAMPLES
        object.add(Array.new(name: :status, type: :string, explode: true))

        assert_equal({%w[filter] => {examples: EXAMPLES}, %w[filter status] => {explode: true}}, object.query_options(prefix: [], version: "2025-06"))
      end

      def test_property_reference
        reference = Reference.new(name: :include, from: Source, property: :expand)

        assert_equal({%w[include] => {explode: false, examples: {single: {value: %w[contact]}}}}, reference.query_options(prefix: [], version: "2025-06"))
      end

      def test_property_reference_with_own_examples
        reference = Reference.new(name: :include, from: Source, property: :expand)
        reference.parameter_examples = EXAMPLES

        assert_equal({%w[include] => {explode: false, examples: EXAMPLES}}, reference.query_options(prefix: [], version: "2025-06"))
      end

      def test_whole_reference
        reference = Reference.new(name: :source, from: Source)

        expected = {%w[source expand] => {explode: false, examples: {single: {value: %w[contact]}}}, %w[source filter status] => {explode: true}}

        assert_equal expected, reference.query_options(prefix: [], version: "2025-06")
      end
    end
  end
end

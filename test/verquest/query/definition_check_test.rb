# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/cat_component"
require_relative "../../support/examples/dog_component"

module Verquest
  module Query
    class DefinitionCheckTest < Minitest::Test
      include ConfigurationTestHelper

      REJECTED = {
        "root one_of" => [
          proc do
            one_of discriminator: :type do
              reference :dog, from: DogComponent
              reference :cat, from: CatComponent
            end
          end,
          "Version '2025-06' has a root-level one_of, which query parameters can't express"
        ],
        "named one_of" => [
          proc do
            field :page, type: :integer
            one_of name: :pet do
              reference :dog, from: DogComponent
              reference :cat, from: CatComponent
            end
          end,
          "Property 'pet' in version '2025-06' is a one_of, which query parameters can't express"
        ],
        "collection" => [
          proc { collection(:items) { field :id, type: :string } },
          "Property 'items' in version '2025-06' is an array of objects or arrays, which query parameters can't express"
        ],
        "array of objects" => [
          proc { array :meta, type: :meta },
          "Property 'meta' in version '2025-06' is an array of objects or arrays, which query parameters can't express"
        ],
        "nested object" => [
          proc { object(:filter) { object(:range) { field :after, type: :string } } },
          "Property 'filter/range' in version '2025-06' is a nested object, which query parameters can't express"
        ],
        "nested nullable object" => [
          proc { object(:filter) { object(:range, nullable: true) { field :after, type: :string } } },
          "Property 'filter/range' in version '2025-06' is a nested object, which query parameters can't express"
        ],
        "nested object field" => [
          proc { object(:filter) { field :meta, type: :meta } },
          "Property 'filter/meta' in version '2025-06' is a nested object, which query parameters can't express"
        ],
        "nested array of objects" => [
          proc { object(:filter) { collection(:items) { field :id, type: :string } } },
          "Property 'filter/items' in version '2025-06' is an array of objects or arrays, which query parameters can't express"
        ]
      }.freeze

      def test_rejected_definitions
        with_configuration(custom_field_types: {meta: {type: "object"}}) do
          REJECTED.each do |label, (definition, message)|
            error = assert_raises(DefinitionError, label) { query_class(&definition) }

            assert_equal message, error.message, label
          end
        end
      end

      def test_allowed_definitions
        klass = query_class do
          field :page, type: :integer
          field :effective_from, type: :string, one_of: [{"type" => "string"}, {"const" => "now"}]
          array :status, type: :string
          object(:filter, nullable: true) do
            field :after, type: :string
            array :site_id, type: :string
          end
          reference :dog, from: DogComponent
        end

        assert_equal :query, klass.location
      end

      PATH_REJECTED = {
        "optional" => [
          proc { field :id, type: :string },
          "Property 'id' in version '2025-06' is optional, but path parameters are always required"
        ],
        "array" => [
          proc { array :id, type: :string, required: true },
          "Property 'id' in version '2025-06' is an array, which path parameters can't express"
        ],
        "object" => [
          proc { object(:id, required: true) { field :value, type: :string } },
          "Property 'id' in version '2025-06' is an object, which path parameters can't express"
        ],
        "nullable object" => [
          proc { object(:id, required: true, nullable: true) { field :value, type: :string } },
          "Property 'id' in version '2025-06' is an object, which path parameters can't express"
        ],
        "named one_of" => [
          proc do
            one_of name: :pet, required: true do
              reference :dog, from: DogComponent
              reference :cat, from: CatComponent
            end
          end,
          "Property 'pet' in version '2025-06' is a one_of, which path parameters can't express"
        ],
        "root one_of" => [
          proc do
            one_of discriminator: :type do
              reference :dog, from: DogComponent
              reference :cat, from: CatComponent
            end
          end,
          "Version '2025-06' has a root-level one_of, which path parameters can't express"
        ]
      }.freeze

      def test_rejected_path_definitions
        PATH_REJECTED.each do |label, (definition, message)|
          error = assert_raises(DefinitionError, label) { path_class(&definition) }

          assert_equal message, error.message, label
        end
      end

      def test_allowed_path_definitions
        klass = path_class do
          field :id, type: :string, required: true, pattern: "^deal_"
          field :number, type: :integer, required: true, nullable: true
          enum :kind, values: %w[a b], required: true
        end

        assert_equal :path, klass.location
      end

      def test_body_classes_are_not_checked
        klass = Class.new(Verquest::Base) do
          version("2025-06") { object(:filter) { object(:range) { field :after, type: :string } } }
        end

        assert_equal :body, klass.location
      end

      private

      def query_class(&definition)
        Class.new(Verquest::Base) do
          location :query
          version("2025-06", &definition)
        end
      end

      def path_class(&definition)
        Class.new(Verquest::Base) do
          location :path
          version("2025-06", &definition)
        end
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/dog_component"
require_relative "../../support/examples/cat_component"

module Verquest
  # Tests that OpenAPI 3.1 validation only reports errors from the variant
  # selected by the oneOf discriminator
  class OneOfDiscriminatorValidationOpenAPI31Test < Minitest::Test
    include ConfigurationTestHelper

    INVALID_DOG = {"type" => "dog", "name" => "Rex", "bogus" => 1}.freeze
    DOG_ERRORS = [{pointer: "/bogus", type: "schema"}].freeze

    def test_root_level_reports_only_selected_variant_errors
      request = build_request { one_of_pets }

      assert_errors DOG_ERRORS, request, INVALID_DOG
    end

    def test_nested_reports_only_selected_variant_errors
      request = build_request do
        one_of_pets(name: :pet)
      end

      assert_errors [{pointer: "/pet/bogus", type: "schema"}], request, {"pet" => INVALID_DOG}
    end

    def test_nullable_reports_only_selected_variant_errors_and_accepts_null
      request = build_request do
        one_of_pets(name: :pet, nullable: true)
      end

      assert_errors [{pointer: "/pet/bogus", type: "schema"}, {pointer: "/pet", type: "null"}], request, {"pet" => INVALID_DOG}
      assert_errors [], request, {"pet" => nil}
    end

    def test_collection_reports_only_selected_variant_errors
      request = build_request do
        collection :pets do
          one_of discriminator: :type do
            reference :dog, from: DogComponent
            reference :cat, from: CatComponent
          end
        end
      end
      params = {"pets" => [{"type" => "cat", "name" => "Tom"}, INVALID_DOG]}

      assert_errors [{pointer: "/pets/1/bogus", type: "schema"}], request, params
    end

    def test_inline_object_variants_report_only_selected_variant_errors
      request = build_request do
        one_of name: :result, discriminator: :status do
          object :success do
            const :status, value: "success"
            field :data, type: :string, required: true
          end

          object :error do
            const :status, value: "error"
            field :message, type: :string, required: true
          end
        end
      end

      assert_errors [{pointer: "/result", type: "required"}], request, {"result" => {"status" => "success"}}
    end

    def test_unknown_discriminator_value_reports_single_error
      request = build_request { one_of_pets }

      assert_errors [{pointer: "", type: "discriminator"}], request, {"type" => "bird", "name" => "Tweety"}
    end

    def test_valid_params_pass
      request = build_request { one_of_pets }

      assert_errors [], request, {"type" => "cat", "name" => "Tom", "meow" => true}
    end

    def test_validation_schema_is_valid_against_meta_schema
      request = build_request { one_of_pets }

      assert request.valid_schema?(version: "2025-06")
    end

    private

    # Builds a request class while OpenAPI 3.1 is configured, because the
    # validation schema is generated when the version block is evaluated
    def build_request(&block)
      with_configuration(json_schema_version: :openapi31) do
        Class.new(Verquest::Base) do
          define_singleton_method(:one_of_pets) do |**options|
            one_of(discriminator: :type, **options) do
              reference :dog, from: DogComponent
              reference :cat, from: CatComponent
            end
          end

          version("2025-06", &block)
        end
      end
    end

    def assert_errors(expected, request, params)
      with_configuration(json_schema_version: :openapi31, validation_error_handling: :result) do
        result = request.process(params, version: "2025-06", validate: true)
        errors = result.success? ? [] : result.errors.map { |error| error.slice(:pointer, :type) }

        assert_equal expected, errors
      end
    end
  end
end

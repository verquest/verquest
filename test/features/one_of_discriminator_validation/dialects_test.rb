# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/dog_component"
require_relative "../../support/examples/cat_component"

module Verquest
  # Tests the discriminator oneOf validation schema under each JSON Schema dialect
  class OneOfDiscriminatorValidationDialectsTest < Minitest::Test
    include ConfigurationTestHelper

    INVALID_DOG = {"pet" => {"type" => "dog", "name" => "Rex", "bogus" => 1}}.freeze
    SELECTED_VARIANT_ERRORS = [{pointer: "/pet/bogus", type: "schema"}].freeze
    ALL_VARIANT_ERRORS = [
      {pointer: "/pet/bogus", type: "schema"},
      {pointer: "/pet/type", type: "const"},
      {pointer: "/pet/bogus", type: "schema"}
    ].freeze
    # The variant components are defined under draft 2020-12, so their schemas
    # use `const`, which draft 4 ignores: the other variant's `type` mismatch is not reported
    ALL_VARIANT_ERRORS_WITHOUT_CONST = [
      {pointer: "/pet/bogus", type: "schema"},
      {pointer: "/pet/bogus", type: "schema"}
    ].freeze

    EXPECTED_ERRORS = {
      draft4: ALL_VARIANT_ERRORS_WITHOUT_CONST,
      draft6: ALL_VARIANT_ERRORS,
      draft7: ALL_VARIANT_ERRORS,
      draft2019_09: ALL_VARIANT_ERRORS,
      draft2020_12: ALL_VARIANT_ERRORS,
      openapi30: SELECTED_VARIANT_ERRORS,
      openapi31: SELECTED_VARIANT_ERRORS
    }.freeze

    EXPECTED_ERRORS.each do |dialect, expected|
      define_method(:"test_#{dialect}_validation_errors") do
        request = build_request(dialect)

        with_configuration(json_schema_version: dialect, validation_error_handling: :result) do
          result = request.process(INVALID_DOG, version: "2025-06", validate: true)

          assert_equal expected, result.errors.map { |error| error.slice(:pointer, :type) }
        end
      end
    end

    # Draft 4 and OpenAPI 3.0 are left out: Verquest#valid_schema? already
    # returns false for them before this change
    %i[draft6 draft7 draft2019_09 draft2020_12 openapi31].each do |dialect|
      define_method(:"test_#{dialect}_validation_schema_is_valid_against_meta_schema") do
        request = build_request(dialect)

        with_configuration(json_schema_version: dialect) do
          assert request.valid_schema?(version: "2025-06")
        end
      end
    end

    def test_validation_schema_is_the_same_for_every_dialect
      schemas = EXPECTED_ERRORS.keys.map { |dialect| build_request(dialect).to_validation_schema(version: "2025-06") }

      assert_equal 1, schemas.uniq.size
    end

    # OpenAPI 3.0 has no `const`, so before the discriminator was kept a valid pet
    # matched both variants and failed. The transformer compiles the inferred
    # variants in the configured version, so the nested `$ref`s must resolve there too.
    def test_openapi30_discriminator_one_of_inside_inferred_variant
      request = with_configuration(json_schema_version: :openapi30) do
        Class.new(Verquest::Base) do
          version "2025-06" do
            one_of name: :owner do
              object :person do
                field :name, type: :string, required: true
                one_of name: :pet, discriminator: :type, required: true do
                  reference :dog, from: DogComponent
                  reference :cat, from: CatComponent
                end
              end

              object :company do
                field :vat_id, type: :string, required: true
              end
            end
          end
        end
      end
      params = {"owner" => {"name" => "Ann", "pet" => {"type" => "cat", "name" => "Tom"}}}

      with_configuration(json_schema_version: :openapi30, validation_error_handling: :result) do
        result = request.process(params, version: "2025-06", validate: true)

        assert_equal({success: true, value: params}, {success: result.success?, value: result.value})
      end
    end

    # Variants that differ only by `const` must still be inferred under dialects
    # without `const` (draft 4, OpenAPI 3.0), because inference reads `const` as a one-value `enum`
    %i[draft4 openapi30].each do |dialect|
      define_method(:"test_#{dialect}_infers_variants_that_differ_only_by_const") do
        request = with_configuration(json_schema_version: dialect) do
          Class.new(Verquest::Base) do
            version "2025-06" do
              one_of name: :shape do
                object :square do
                  const :kind, value: "square"
                  field :size, type: :integer
                end

                object :circle do
                  const :kind, value: "circle"
                  field :size, type: :integer
                end
              end
            end
          end
        end
        params = {"shape" => {"kind" => "square", "size" => 2}}

        with_configuration(json_schema_version: dialect) do
          assert_equal params, request.process(params, version: "2025-06", validate: false)
        end
      end
    end

    private

    # Builds the request while the dialect is configured, so the test does not
    # depend on when the validation schema is generated
    def build_request(dialect)
      with_configuration(json_schema_version: dialect) do
        Class.new(Verquest::Base) do
          version "2025-06" do
            one_of name: :pet, discriminator: :type do
              reference :dog, from: DogComponent
              reference :cat, from: CatComponent
            end
          end
        end
      end
    end
  end
end

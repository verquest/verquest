# frozen_string_literal: true

require "test_helper"

require_relative "../support/examples/dog_component"
require_relative "../support/examples/cat_component"

module Verquest
  # Schema options, like a description, on a named one_of
  class OneOfSchemaOptionsTest < Minitest::Test
    include ConfigurationTestHelper

    DESCRIPTION = "The pet of the owner."
    ANNOTATIONS = "description, title, examples, example, deprecated, readOnly, writeOnly, externalDocs, $comment"

    class PetRequest < Verquest::Base
      version "2025-06" do
        field :owner_name, type: :string, required: true

        one_of name: :pet, discriminator: :type, required: true, description: DESCRIPTION, read_only: true do
          reference :dog, from: DogComponent
          reference :cat, from: CatComponent
        end
      end
    end

    class NullablePetRequest < Verquest::Base
      version "2025-06" do
        one_of name: :pet, discriminator: :type, nullable: true, description: DESCRIPTION do
          reference :dog, from: DogComponent
          reference :cat, from: CatComponent
        end
      end
    end

    class DefaultOptionsRequest < Verquest::Base
      version "2025-06" do
        with_options(description: DESCRIPTION) do
          one_of name: :value do
            object(:text) { field :content, type: :string, required: true }
            object(:number) { field :amount, type: :number, required: true }
          end
        end
      end
    end

    def test_schema_has_the_options_next_to_one_of
      pet = PetRequest.to_schema(version: "2025-06")["properties"]["pet"]

      assert_equal({"description" => DESCRIPTION, "readOnly" => true}, pet.slice("description", "readOnly"))
      assert_equal 2, pet["oneOf"].size
      assert_equal "type", pet.dig("discriminator", "propertyName")
    end

    def test_validation_schema_leaves_out_the_annotations
      pet = PetRequest.to_validation_schema(version: "2025-06")["properties"]["pet"]

      assert_empty pet.keys & %w[description readOnly]
      assert_equal 2, pet["oneOf"].size
    end

    def test_nullable_schema_has_the_options_next_to_the_null_union
      pet = NullablePetRequest.to_schema(version: "2025-06")["properties"]["pet"]

      assert_equal DESCRIPTION, pet["description"]
      assert_equal [{"type" => "null"}], pet["anyOf"].drop(1)
      refute pet["anyOf"].first.key?("description")
    end

    class DefaultPetRequest < Verquest::Base
      version "2025-06" do
        one_of name: :pet, discriminator: :type, nullable: true, default: nil, "x-internal": true, "$comment": "Nullable pet" do
          reference :dog, from: DogComponent
          reference :cat, from: CatComponent
        end
      end
    end

    def test_nullable_schema_keeps_a_null_default
      pet = DefaultPetRequest.to_schema(version: "2025-06")["properties"]["pet"]

      assert_equal({"default" => nil, "x-internal" => true, "$comment" => "Nullable pet"}, pet.slice("default", "x-internal", "$comment"))
    end

    def test_validation_schema_keeps_only_the_default
      pet = DefaultPetRequest.to_validation_schema(version: "2025-06")["properties"]["pet"]

      assert_equal({"default" => nil}, pet.slice("default", "x-internal", "$comment"))
    end

    def test_missing_nullable_one_of_receives_a_null_default
      with_configuration(insert_property_defaults: true) do
        assert_equal({"pet" => nil}, DefaultPetRequest.process({}, version: "2025-06", validate: true))
      end
    end

    def test_openapi30_nullable_schema_keeps_the_options
      with_configuration(json_schema_version: :openapi30) do
        request = Class.new(Verquest::Base) do
          version "2025-06" do
            one_of name: :pet, discriminator: :type, nullable: true, description: DESCRIPTION do
              reference :dog, from: DogComponent
              reference :cat, from: CatComponent
            end
          end
        end
        pet = request.to_schema(version: "2025-06")["properties"]["pet"]

        assert_equal DESCRIPTION, pet["description"]
        assert pet["nullable"]
      end
    end

    class InheritingRequest < Verquest::Base
      version "2025-06" do
        one_of name: :pet, discriminator: :type, description: DESCRIPTION do
          reference :dog, from: DogComponent
          reference :cat, from: CatComponent
        end
      end

      version "2025-07" do
        field :owner_name, type: :string
      end
    end

    class ReferencingRequest < Verquest::Base
      version "2025-06" do
        reference :animal, from: DefaultPetRequest, property: :pet
      end
    end

    class CollectionRequest < Verquest::Base
      version "2025-06" do
        collection :owners do
          one_of name: :pet, discriminator: :type, description: DESCRIPTION do
            reference :dog, from: DogComponent
            reference :cat, from: CatComponent
          end
        end
      end
    end

    class StructuralDefaultsRequest < Verquest::Base
      version "2025-06" do
        with_options(additional_properties: false, discriminator: :kind, parameter_examples: {"dog" => {"value" => "dog"}}, example: "abc", title: "Pet") do
          one_of name: :pet, discriminator: :type do
            reference :dog, from: DogComponent
            reference :cat, from: CatComponent
          end
        end
      end
    end

    def test_inherited_version_keeps_the_options
      pet = InheritingRequest.to_schema(version: "2025-07")["properties"]["pet"]

      assert_equal DESCRIPTION, pet["description"]
    end

    def test_reference_to_the_property_keeps_the_default
      animal = ReferencingRequest.to_validation_schema(version: "2025-06")["properties"]["animal"]

      assert_equal({"default" => nil}, animal.slice("default", "x-internal"))
    end

    def test_renamed_copy_keeps_the_options
      one_of = Properties::OneOf.new(name: :pet, description: DESCRIPTION)

      assert_equal({"animal" => {"oneOf" => [], "description" => DESCRIPTION}}, one_of.renamed(name: :animal, map: nil).to_schema)
    end

    def test_one_of_in_a_collection_has_the_options
      pet = CollectionRequest.to_schema(version: "2025-06").dig("properties", "owners", "items", "properties", "pet")

      assert_equal DESCRIPTION, pet["description"]
    end

    def test_with_options_defaults_apply_only_annotations
      pet = StructuralDefaultsRequest.to_schema(version: "2025-06")["properties"]["pet"]

      assert_equal({"title" => "Pet", "propertyName" => "type"}, {"title" => pet["title"], "propertyName" => pet.dig("discriminator", "propertyName")})
      assert_empty pet.keys & %w[additionalProperties parameterExamples example]
    end

    def test_with_options_structural_defaults_leave_validation_alone
      params = {"pet" => {"type" => "dog", "name" => "Rex"}}

      assert_equal params, StructuralDefaultsRequest.process(params, version: "2025-06")
    end

    def test_with_options_defaults_apply
      value = DefaultOptionsRequest.to_schema(version: "2025-06")["properties"]["value"]

      assert_equal DESCRIPTION, value["description"]
    end

    def test_schemas_are_valid
      requests = [PetRequest, NullablePetRequest, DefaultPetRequest, DefaultOptionsRequest, CollectionRequest, StructuralDefaultsRequest, ReferencingRequest]

      assert_equal requests.to_h { |request| [request, true] }, requests.to_h { |request| [request, request.valid_schema?(version: "2025-06")] }
    end

    def test_validation_is_unchanged
      dog = {"type" => "dog", "name" => "Rex", "bark" => true}
      expected = {
        [PetRequest, {"owner_name" => "John", "pet" => dog}] => true,
        [PetRequest, {"owner_name" => "John", "pet" => {"type" => "dog"}}] => false,
        [NullablePetRequest, {"pet" => nil}] => true,
        [NullablePetRequest, {"pet" => dog}] => true,
        [NullablePetRequest, {"pet" => {"type" => "fish"}}] => false,
        [DefaultOptionsRequest, {"value" => {"amount" => 1}}] => true,
        [DefaultOptionsRequest, {"value" => {"amount" => "1"}}] => false
      }

      actual = with_configuration(validation_error_handling: :result) do
        expected.to_h { |(request, params), _| [[request, params], request.process(params, version: "2025-06").success?] }
      end

      assert_equal expected, actual
    end

    NOT_ALLOWED_OPTIONS = {
      {additional_properties: false, one_of: []} => "additionalProperties, oneOf",
      {min_properties: 5, dependent_schemas: {"name" => {"required" => ["bark"]}}} => "minProperties, dependentSchemas",
      {"$schema": "https://json-schema.org/draft/2019-09/schema", format: "email"} => "$schema, format",
      {parameter_examples: {}, case_insensitive: true, explode: false, item_schema_options: {}} => "parameterExamples, caseInsensitive, explode, itemSchemaOptions"
    }.freeze

    def test_options_other_than_annotations_raise
      messages = NOT_ALLOWED_OPTIONS.keys.to_h do |options|
        error = assert_raises(DefinitionError) do
          Class.new(Verquest::Base) do
            version "2025-06" do
              one_of name: :pet, discriminator: :type, **options do
                reference :dog, from: DogComponent
                reference :cat, from: CatComponent
              end
            end
          end
        end
        [options, error.message]
      end

      expected = NOT_ALLOWED_OPTIONS.transform_values do |keys|
        "one_of 'pet' can't take #{keys}, it takes only #{ANNOTATIONS}, default and x- extensions"
      end

      assert_equal expected, messages
    end

    def test_unnamed_one_of_in_a_collection_with_schema_options_raises
      error = assert_raises(DefinitionError) do
        Class.new(Verquest::Base) do
          version "2025-06" do
            collection :pets do
              one_of discriminator: :type, description: DESCRIPTION do
                reference :dog, from: DogComponent
                reference :cat, from: CatComponent
              end
            end
          end
        end
      end

      assert_equal "An unnamed one_of in version '2025-06' can't take schema options (description), give it a name: or put the options on the enclosing property", error.message
    end

    def test_unnamed_one_of_with_schema_options_raises
      error = assert_raises(DefinitionError) do
        Class.new(Verquest::Base) do
          version "2025-06" do
            one_of discriminator: :type, description: DESCRIPTION do
              reference :dog, from: DogComponent
              reference :cat, from: CatComponent
            end
          end
        end
      end

      assert_equal "An unnamed one_of in version '2025-06' can't take schema options (description), give it a name: or describe the version", error.message
    end

    def test_root_one_of_takes_the_version_annotations
      request = Class.new(Verquest::Base) do
        version "2025-06" do
          description DESCRIPTION
          schema_options "x-root": true, "$comment": "Pets"

          one_of discriminator: :type do
            reference :dog, from: DogComponent
            reference :cat, from: CatComponent
          end
        end
      end

      schema = request.to_schema(version: "2025-06")

      assert_equal({"description" => DESCRIPTION, "x-root" => true, "$comment" => "Pets"}, schema.except("oneOf", "discriminator"))
      refute request.to_validation_schema(version: "2025-06").key?("description")
    end

    def test_root_one_of_with_other_version_schema_options_raises
      error = assert_raises(DefinitionError) do
        Class.new(Verquest::Base) do
          schema_options additional_properties: true

          version "2025-06" do
            schema_options default: {}, min_properties: 1, "x-root": true

            one_of discriminator: :type do
              reference :dog, from: DogComponent
              reference :cat, from: CatComponent
            end
          end
        end
      end

      assert_equal "The root one_of of version '2025-06' can't take schema options (default, minProperties), " \
        "it takes only annotations and x- extensions", error.message
    end

    def test_unnamed_one_of_error_leaves_the_definition_usable
      request = Class.new(Verquest::Base) do
        version "2025-06" do
          with_options(required: true) do
            one_of(discriminator: :type, description: DESCRIPTION) { reference :dog, from: DogComponent }
          rescue DefinitionError
            field :name, type: :string
          end
        end
      end

      assert_equal({"type" => "object", "required" => ["name"], "properties" => {"name" => {"type" => "string"}}, "additionalProperties" => false},
        request.to_schema(version: "2025-06"))
    end

    def test_default_with_dependent_properties_raises
      error = assert_raises(DefinitionError) do
        Class.new(Verquest::Base) do
          version "2025-06" do
            field :other, type: :string
            one_of name: :pet, discriminator: :type, required: [:other], default: {"type" => "dog", "name" => "Rex"} do
              reference :dog, from: DogComponent
              reference :cat, from: CatComponent
            end
          end
        end
      end

      assert_equal "one_of 'pet' has a default and requires other, so every request without pet would need other", error.message
    end

    def test_unnamed_one_of_ignores_with_options_defaults
      request = Class.new(Verquest::Base) do
        version "2025-06" do
          with_options(description: DESCRIPTION) do
            one_of discriminator: :type do
              reference :dog, from: DogComponent
              reference :cat, from: CatComponent
            end
          end
        end
      end

      refute request.to_schema(version: "2025-06").key?("description")
    end

    class HashDefaultRequest < Verquest::Base
      version "2025-06" do
        one_of name: :pet, default: {"kind" => "dog", "tags" => ["good"]} do
          object(:dog) do
            const :kind, value: "dog", required: true
            array :tags, type: :string
          end
          object(:cat) { const :kind, value: "cat", required: true }
        end
      end
    end

    def test_changing_an_inserted_default_leaves_later_requests_alone
      with_configuration(insert_property_defaults: true) do
        HashDefaultRequest.process({}, version: "2025-06")["pet"]["tags"] << "changed"

        assert_equal({"pet" => {"kind" => "dog", "tags" => ["good"]}}, HashDefaultRequest.process({}, version: "2025-06"))
      end
    end

    INVALID_DEFAULTS = {
      {default: nil} => "one_of 'pet' has a default, nil, that doesn't match its schema",
      {default: "fish"} => "one_of 'pet' has a default, \"fish\", that doesn't match its schema"
    }.freeze

    def test_default_that_doesnt_match_the_schema_raises
      messages = INVALID_DEFAULTS.keys.to_h do |options|
        error = assert_raises(DefinitionError) do
          Class.new(Verquest::Base) do
            version "2025-06" do
              one_of name: :pet, discriminator: :type, **options do
                reference :dog, from: DogComponent
                reference :cat, from: CatComponent
              end
            end
          end
        end
        [options, error.message]
      end

      assert_equal INVALID_DEFAULTS, messages
    end

    class AnnotatedVariantsRequest < Verquest::Base
      version "2025-06" do
        with_options(description: DESCRIPTION, example: "abc") do
          one_of name: :value do
            object(:text) { field :content, type: :string, required: true }
            object(:number) { field :amount, type: :number, required: true }
          end
          field :label, type: :string
        end
      end
    end

    # The oneOf holds the annotations it takes, and the variants keep the examples it leaves out
    def test_with_options_annotations_skip_the_variants
      properties = AnnotatedVariantsRequest.to_schema(version: "2025-06")["properties"]
      variant_schemas = properties["value"]["oneOf"].flat_map { |variant| [variant, *variant["properties"].values] }

      assert_equal [DESCRIPTION, DESCRIPTION], [properties["value"]["description"], properties["label"]["description"]]
      assert_empty variant_schemas.flat_map { |schema| schema.keys & %w[description] }
      assert_equal ["abc"] * 4, variant_schemas.map { |schema| schema["example"] }
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module Verquest
  # OpenAPI 3.0 documents have no "null" type, while validation keeps accepting nil
  class Openapi30DocumentsTest < Minitest::Test
    include ConfigurationTestHelper

    extend ConfigurationTestHelper

    class Address < Verquest::Base
      version("2025-06") { field :city, type: :string }
    end

    # Defined under OpenAPI 3.0, so their documents write const as a one-value enum
    with_configuration(json_schema_version: :openapi30) do
      %w[dog cat].each do |kind|
        const_set(kind.capitalize, Class.new(Verquest::Base) { version("2025-06") { const :type, value: kind, required: true } })
      end
    end

    PARAMS = {
      "name" => nil, "tags" => nil, "meta" => nil, "items" => nil, "size" => nil,
      "limit" => nil, "address" => nil, "kind" => nil, "value" => nil, "pet" => nil
    }.freeze

    def build_request
      Class.new(Verquest::Base) do
        version("2025-06") do
          field :name, type: :string, nullable: true
          array :tags, type: :string, nullable: true
          object(:meta, nullable: true) { field :note, type: :string }
          collection(:items, nullable: true) { field :id, type: :string }
          enum :size, values: %w[s m], nullable: true
          enum :limit, values: [10, "all"], nullable: true
          reference :address, from: Address, nullable: true
          const :kind, value: "user", nullable: true
          one_of name: :value, nullable: true do
            object(:text) { field :content, type: :string, required: true }
            object(:number) { field :amount, type: :number, required: true }
          end
          one_of name: :pet, nullable: true, discriminator: :type do
            reference :dog, from: Dog
            reference :cat, from: Cat
          end
          field :owner, type: :string, required: [:name]
        end
      end
    end

    # The mixed enum carries nullable on each anyOf branch instead
    def test_openapi30_schema_uses_nullable
      with_configuration(json_schema_version: :openapi30) do
        properties = build_request.to_schema(version: "2025-06")["properties"]

        refute_includes JSON.generate(properties), '"null"'
        assert_equal PARAMS.keys - ["limit"], properties.select { |_, schema| schema["nullable"] }.keys
      end
    end

    def test_openapi30_reference_and_type_union
      with_configuration(json_schema_version: :openapi30) do
        properties = build_request.to_schema(version: "2025-06")["properties"]

        assert_equal({"allOf" => [{"$ref" => Address.to_ref}], "nullable" => true}, properties["address"])
        assert_equal [{"type" => "integer", "nullable" => true}, {"type" => "string", "nullable" => true}], properties["limit"]["anyOf"]
      end
    end

    # Null stays outside the discriminated oneOf, as in versponse
    def test_openapi30_discriminated_one_of_is_wrapped
      with_configuration(json_schema_version: :openapi30) do
        pet = build_request.to_schema(version: "2025-06")["properties"]["pet"]

        assert_equal [%w[oneOf discriminator], true], [pet["allOf"].first.keys, pet["nullable"]]
      end
    end

    def test_openapi30_document_is_valid
      with_configuration(json_schema_version: :openapi30) do
        request = build_request

        assert_empty JSONSchemer.openapi(openapi_document(request)).validate.map { |error| error["data_pointer"] }
        assert request.valid_schema?(version: "2025-06")
      end
    end

    def test_openapi30_validation_accepts_nil
      with_configuration(json_schema_version: :openapi30) do
        request = build_request

        assert_includes JSON.generate(request.to_validation_schema(version: "2025-06")), '"null"'
        assert_equal PARAMS, request.process(PARAMS, version: "2025-06")
      end
    end

    def openapi_document(request)
      components = [Address, Dog, Cat].to_h { |klass| [klass.component_name, klass.to_schema(version: "2025-06")] }
      components["Request"] = request.to_schema(version: "2025-06")

      {"openapi" => "3.0.3", "info" => {"title" => "Test", "version" => "1"}, "paths" => {}, "components" => {"schemas" => components}}
    end

    def test_other_versions_keep_json_schema_forms
      properties = build_request.to_schema(version: "2025-06")["properties"]

      refute_includes JSON.generate(properties), '"nullable"'
      assert_equal %w[string null], properties["name"]["type"]
    end
  end
end

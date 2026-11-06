# frozen_string_literal: true

require "test_helper"

module Verquest
  # OpenAPI 3.0 documents have no "null" type, while validation keeps accepting nil
  class Openapi30DocumentsTest < Minitest::Test
    include ConfigurationTestHelper

    class Address < Verquest::Base
      version("2025-06") { field :city, type: :string }
    end

    PARAMS = {
      "name" => nil, "tags" => nil, "meta" => nil, "items" => nil, "size" => nil,
      "limit" => nil, "address" => nil, "kind" => nil, "value" => nil
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

    def test_openapi30_validation_accepts_nil
      with_configuration(json_schema_version: :openapi30) do
        request = build_request

        assert_includes JSON.generate(request.to_validation_schema(version: "2025-06")), '"null"'
        assert_equal PARAMS, request.process(PARAMS, version: "2025-06")
      end
    end

    def test_other_versions_keep_json_schema_forms
      properties = build_request.to_schema(version: "2025-06")["properties"]

      refute_includes JSON.generate(properties), '"nullable"'
      assert_equal %w[string null], properties["name"]["type"]
    end
  end
end

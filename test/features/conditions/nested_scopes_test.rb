# frozen_string_literal: true

require "test_helper"

require_relative "../../support/examples/simple_request"

module Verquest
  # Tests conditions in nested objects, inline collection items and oneOf variant objects
  class ConditionsNestedScopesTest < Minitest::Test
    include ConfigurationTestHelper

    COMPANY_CONDITION = {
      "if" => {"required" => %w[kind], "properties" => {"kind" => {"const" => "company"}}},
      "then" => {"required" => %w[vat_id]},
      "else" => {"properties" => {"vat_id" => false}}
    }.freeze

    def test_object
      request = build_request do
        object :customer do
          company_condition
        end
      end

      customer_schema = request.to_validation_schema(version: "2025-09")["properties"]["customer"]

      assert_equal %w[kind vat_id], customer_schema["properties"].keys
      assert_equal COMPANY_CONDITION, customer_schema.slice("if", "then", "else")
      assert_equal({"customer/kind" => "customer/kind", "customer/vat_id" => "company_vat_id"}, request.mapping(version: "2025-09"))
    end

    def test_object_errors_and_process
      request = build_request do
        object :customer do
          company_condition
        end
      end

      assert_equal [{pointer: "/customer", type: "required"}], errors(request, {"customer" => {"kind" => "company"}})
      assert_equal [{pointer: "/customer/vat_id", type: "schema"}], errors(request, {"customer" => {"kind" => "person", "vat_id" => "CZ1"}})
      assert_equal({"customer" => {"kind" => "company"}, "company_vat_id" => "CZ1"}, request.process({"customer" => {"kind" => "company", "vat_id" => "CZ1"}}, version: "2025-09"))
    end

    def test_inline_collection
      request = build_request do
        collection :customers do
          company_condition
        end
      end

      items_schema = request.to_schema(version: "2025-09")["properties"]["customers"]["items"]

      assert_equal %w[kind vat_id], items_schema["properties"].keys
      assert_equal COMPANY_CONDITION, items_schema.slice("if", "then", "else")
      assert_equal [{pointer: "/customers/1/vat_id", type: "schema"}], errors(request, {"customers" => [{"kind" => "company", "vat_id" => "CZ1"}, {"kind" => "person", "vat_id" => "CZ2"}]})
    end

    def test_inline_collection_mapping
      request = build_request do
        collection :customers do
          company_condition
        end
      end

      assert_equal({"customers[]/kind" => "customers[]/kind", "customers[]/vat_id" => "company_vat_id"}, request.mapping(version: "2025-09"))
    end

    def test_one_of_variant_object
      request = build_request do
        one_of name: :party, discriminator: :type do
          object :business do
            const :type, value: "business"
            company_condition
          end
          object :private do
            const :type, value: "private"
          end
        end
      end

      business_schema = request.to_schema(version: "2025-09")["properties"]["party"]["oneOf"].first

      assert_equal COMPANY_CONDITION, business_schema.slice("if", "then", "else")
      assert_equal(
        {"party" => {"type" => "business", "kind" => "company"}, "company_vat_id" => "CZ1"},
        request.process({"party" => {"type" => "business", "kind" => "company", "vat_id" => "CZ1"}}, version: "2025-09")
      )
    end

    def test_collection_with_item_raises
      error = assert_raises(ArgumentError) do
        build_request do
          collection :requests, item: SimpleRequest do
            condition { given { present :name } }
          end
        end
      end

      assert_equal "condition can not be declared in a collection defined by item:", error.message
    end

    def test_collection_with_one_of_items_raises
      error = assert_raises(ArgumentError) do
        build_request do
          collection :parties do
            one_of discriminator: :type do
              object(:business) { const :type, value: "business" }
            end
            condition do
              given { present :type }
              then_apply { field :vat_id, type: :string }
            end
          end
        end
      end

      assert_equal "Conditions can not be declared next to a one_of in a collection", error.message
    end

    private

    def build_request(&block)
      Class.new(Verquest::Base) do
        define_singleton_method(:company_condition) do
          field :kind, type: :string
          condition do
            given { equals :kind, "company" }
            then_apply { field :vat_id, type: :string, required: true, map: "/company_vat_id" }
          end
        end

        version("2025-09", &block)
      end
    end

    def errors(request, params)
      with_configuration(validation_error_handling: :result) do
        result = request.process(params, version: "2025-09", validate: true)
        result.success? ? [] : result.errors.map { |error| error.slice(:pointer, :type) }
      end
    end
  end
end

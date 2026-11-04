# frozen_string_literal: true

require "test_helper"

module Verquest
  class ConditionClassMethodsTest < Minitest::Test
    include ConfigurationTestHelper

    def test_condition_with_given_and_both_branches
      request = build_request do
        field :kind, type: :string
        condition :company do
          given { equals :kind, "company" }
          then_apply { field :vat_id, type: :string, required: true }
          else_apply { field :birth_date, type: :string }
        end
      end

      expected = {
        "if" => {"required" => %w[kind], "properties" => {"kind" => {"const" => "company"}}},
        "then" => {"required" => %w[vat_id], "properties" => {"birth_date" => false}},
        "else" => {"properties" => {"vat_id" => false}}
      }

      assert_equal expected, request.to_schema(version: "2025-09").slice("if", "then", "else")
      assert_equal %w[kind vat_id birth_date], request.to_schema(version: "2025-09")["properties"].keys
    end

    def test_rules
      request = build_request do
        field :kind, type: :string
        field :age, type: :integer
        field :email, type: :string
        field :phone, type: :string
        condition do
          given do
            value_in :kind, %w[person child]
            satisfies :age, exclusive_minimum: 17
          end
          then_apply do
            any do
              present :email
              present :phone
            end
          end
          else_apply do
            absent :email
            none { equals :phone, "" }
          end
        end
      end

      expected = {
        "if" => {"required" => %w[kind age], "properties" => {"kind" => {"enum" => %w[person child]}, "age" => {"exclusiveMinimum" => 17}}},
        "then" => {"anyOf" => [{"required" => %w[email]}, {"required" => %w[phone]}]},
        "else" => {"properties" => {"email" => false}, "not" => {"anyOf" => [{"properties" => {"phone" => {"const" => ""}}}]}}
      }

      assert_equal expected, request.to_schema(version: "2025-09").slice("if", "then", "else")
    end

    def test_with_options_applies_in_branches
      request = build_request do
        field :kind, type: :string
        condition do
          given { present :kind }
          then_apply do
            with_options(required: true) { field :vat_id, type: :string }
          end
        end
      end

      assert_equal({"required" => %w[vat_id]}, request.to_schema(version: "2025-09")["then"])
    end

    def test_process_keeps_root_branch_properties
      request = build_request do
        field :kind, type: :string
        condition do
          given { equals :kind, "company" }
          then_apply { field :vat_id, type: :string, required: true, map: "company/vat" }
        end
      end

      assert_equal({"kind" => "company", "company" => {"vat" => "CZ1"}}, request.process({"kind" => "company", "vat_id" => "CZ1"}, version: "2025-09"))
    end

    def test_rules_outside_a_condition_raise
      error = assert_raises(ArgumentError) { build_request { present :kind } }

      assert_equal "Rules can only be used inside given, then_apply, else_apply, depends_on, any or none", error.message
    end

    def test_parts_outside_a_condition_raise
      error = assert_raises(ArgumentError) { build_request { then_apply { field :kind, type: :string } } }

      assert_equal "given, then_apply and else_apply can only be used inside a condition", error.message
    end

    def test_condition_outside_a_supported_scope_raises
      error = assert_raises(ArgumentError) do
        build_request do
          field :kind, type: :string
          condition do
            given { present :kind }
            then_apply { condition { given { present :kind } } }
          end
        end
      end

      assert_equal "condition can only be declared in a version, object or inline collection", error.message
    end

    def test_properties_inside_given_raise
      error = assert_raises(ArgumentError) do
        build_request do
          field :kind, type: :string
          condition do
            then_apply { field :vat_id, type: :string }
            given do
              present :kind
              field :other, type: :string
            end
          end
        end
      end

      assert_equal "Properties can not be declared inside given, any or none", error.message
    end

    private

    def build_request(&block)
      Class.new(Verquest::Base) do
        version("2025-09", &block)
      end
    end
  end
end

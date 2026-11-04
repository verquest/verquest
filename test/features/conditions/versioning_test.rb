# frozen_string_literal: true

require "test_helper"

module Verquest
  # Tests condition inheritance and exclude_conditions
  class ConditionsVersioningTest < Minitest::Test
    def test_conditions_are_inherited
      schema = build_request.to_schema(version: "2025-10")

      assert_equal %w[kind credit_card note vat_id billing_address], schema["properties"].keys
      assert_equal 2, schema["allOf"].size
    end

    def test_exclude_conditions
      request = build_request do
        version("2025-11") { exclude_conditions :company }
      end
      schema = request.to_schema(version: "2025-11")

      assert_equal({"required" => %w[credit_card]}, schema["if"])
      assert_equal %w[kind credit_card note billing_address], schema["properties"].keys
      assert_equal 2, request.resolve("2025-10").conditions.size
    end

    def test_redeclaring_an_inherited_condition_raises
      error = assert_raises(ArgumentError) do
        build_request do
          version "2025-11" do
            condition :company do
              given { equals :kind, "person" }
              then_apply { field :birth_date, type: :string }
            end
          end
        end
      end

      assert_equal "Condition 'company' is already defined", error.message
    end

    def test_redeclaring_after_exclude_conditions
      request = build_request do
        version "2025-11" do
          exclude_conditions :company
          condition :company do
            given { equals :kind, "person" }
            then_apply { field :birth_date, type: :string }
          end
        end
      end

      expected_if = {"required" => %w[kind], "properties" => {"kind" => {"const" => "person"}}}

      assert_equal expected_if, request.to_schema(version: "2025-11")["allOf"].last["if"]
    end

    def test_exclude_unknown_condition_raises
      error = assert_raises(ArgumentError) do
        Class.new(Verquest::Base) do
          version("2025-09") { exclude_conditions :missing }
        end
      end

      assert_equal "Condition 'missing' is not defined", error.message
    end

    def test_excluding_a_property_used_by_an_inherited_condition_raises
      error = assert_raises(ArgumentError) do
        Class.new(Verquest::Base) do
          version "2025-09" do
            field :kind, type: :string
            depends_on(:kind, :kind) { field :vat_id, type: :string }
          end

          version("2025-10", exclude_properties: %i[kind]) {}
        end
      end

      assert_equal "Condition 'kind' uses unknown properties: kind", error.message
    end

    private

    def build_request(&later_versions)
      Class.new(Verquest::Base) do
        version "2025-09" do
          field :kind, type: :string
          field :credit_card, type: :string

          condition :company do
            given { equals :kind, "company" }
            then_apply { field :vat_id, type: :string, required: true }
          end

          depends_on :credit_card do
            field :billing_address, type: :string
          end
        end

        version("2025-10") { field :note, type: :string }

        class_exec(&later_versions) if later_versions
      end
    end
  end
end

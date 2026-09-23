# frozen_string_literal: true

require "test_helper"

module Verquest
  class NullableConstraintsTest < Minitest::Test
    include ConfigurationTestHelper

    class Source < Verquest::Base
      version "2025-06" do
        enum :role, values: %w[member admin]
        const :kind, value: "user"
        field :label, type: :string, nullable: true
        field :state, type: :string, enum: %w[active inactive]
        one_of name: :choice do
          object :first do
            const :kind, value: "first", required: true
          end
          object :second do
            const :kind, value: "second", required: true
          end
        end
      end
    end

    %i[role kind label state].each do |property|
      define_method("test_nullable_reference_to_#{property}") do
        request = Class.new(Verquest::Base) do
          version "2025-06" do
            reference :value, from: Source, property: property, nullable: true
          end
        end

        assert_nullable_request(request)
      end
    end

    def test_nullable_reference_to_one_of_schema
      reference = Properties::Reference.new(name: :value, from: Source, property: :choice, nullable: true)
      schema = reference.to_validation_schema(version: "2025-06")["value"]
      validator = JSONSchemer.schema(schema)

      assert validator.valid?(nil)
      assert validator.valid?({"kind" => "first"})
      refute validator.valid?({"kind" => "unknown"})
    end

    def test_nullable_reference_preserves_non_null_constraints
      reference = Properties::Reference.new(name: :value, from: Source, property: :state, nullable: true)
      schema = reference.to_validation_schema(version: "2025-06")["value"]

      assert JSONSchemer.schema(schema).valid?("active")
      ["unknown", 1].each do |value|
        refute JSONSchemer.schema(schema).valid?(value)
      end
      refute JSONSchemer.schema(Source.to_validation_schema(version: "2025-06", property: :state)).valid?(nil)
    end

    def test_nullable_field_with_enum
      values = %w[active inactive].freeze
      request = Class.new(Verquest::Base) do
        version "2025-06" do
          field :value, type: :string, enum: values, nullable: true
        end
      end

      assert_nullable_request(request)
      %w[null unknown].each { |value| assert_rejects(request, value) }
      assert_equal({"value" => "active"}, request.process({"value" => "active"}, version: "2025-06", validate: true))
    end

    def test_nullable_custom_enum_field_preserves_shared_values
      values = %w[active inactive].freeze
      custom_types = {state: {type: "string", schema_options: {enum: values}}}

      with_configuration(custom_field_types: custom_types) do
        nullable = Properties::Field.new(name: :value, type: :state, nullable: true)
        required_type = Properties::Field.new(name: :value, type: :state)

        assert_equal ["active", "inactive", nil], nullable.to_schema["value"]["enum"]
        assert_equal %w[active inactive], required_type.to_schema["value"]["enum"]
        assert_equal %w[active inactive], values
      end
    end

    def test_nullable_const
      request = Class.new(Verquest::Base) do
        version "2025-06" do
          const :value, value: "user", nullable: true
        end
      end

      assert_nullable_request(request)
      %w[null admin].each { |value| assert_rejects(request, value) }
      assert_equal({"value" => "user"}, request.process({"value" => "user"}, version: "2025-06", validate: true))
    end

    def test_const_inherits_scoped_nullability
      request = Class.new(Verquest::Base) do
        version "2025-06" do
          with_options nullable: true, required: true do
            const :value, value: "user"
          end
        end
      end

      assert_nullable_request(request)
      assert_rejects(request, "admin")
      assert_raises(InvalidParamsError) { request.process({}, version: "2025-06", validate: true) }
    end

    def test_const_can_override_scoped_nullability_with_false
      request = Class.new(Verquest::Base) do
        version "2025-06" do
          with_options nullable: true do
            const :value, value: "user", nullable: false
          end
        end
      end

      assert_rejects(request, nil)
      assert_equal({"const" => "user"}, request.to_schema(version: "2025-06")["properties"]["value"])
    end

    def test_const_can_override_scoped_nullability_with_true
      request = Class.new(Verquest::Base) do
        version "2025-06" do
          with_options nullable: false do
            const :value, value: "user", nullable: true
          end
        end
      end

      assert_nullable_request(request)
    end

    def test_const_nullability_does_not_leak_out_of_scope
      request = Class.new(Verquest::Base) do
        version "2025-06" do
          with_options nullable: true do
            const :nullable_value, value: "user"
          end
          const :value, value: "user"
        end
      end

      assert_rejects(request, nil)
      assert_equal({"nullable_value" => nil}, request.process({"nullable_value" => nil}, version: "2025-06", validate: true))
    end

    def test_nullable_null_constant_remains_null_only
      property = Properties::Const.new(name: :value, value: nil, nullable: true)
      validator = JSONSchemer.schema(property.to_validation_schema["value"])

      assert validator.valid?(nil)
      refute validator.valid?("null")
    end

    def test_non_nullable_constant_rejects_null
      property = Properties::Const.new(name: :value, value: "user", nullable: false)
      validator = JSONSchemer.schema(property.to_validation_schema["value"])

      assert validator.valid?("user")
      refute validator.valid?(nil)
    end

    def test_nullable_one_of_with_nullable_variants
      request = Class.new(Verquest::Base) do
        version "2025-06" do
          one_of name: :value, nullable: true do
            object :first, nullable: true do
              field :label, type: :string
            end
            object :second, nullable: true do
              field :label, type: :string
              field :extra, type: :string, required: true
            end
          end
        end
      end

      assert_nullable_request(request)
      assert_rejects(request, "null")
      params = {"value" => {"label" => "hello"}}

      assert_equal params, request.process(params, version: "2025-06", validate: true)
    end

    def test_nullable_one_of_still_rejects_ambiguous_non_null_values
      one_of = Properties::OneOf.new(name: :value, nullable: true)
      %i[first second].each do |name|
        one_of.add(Properties::Object.new(name: name, nullable: true))
      end

      [one_of.to_schema, one_of.to_validation_schema(version: "2025-06")].each do |schema|
        validator = JSONSchemer.schema(schema["value"])

        assert validator.valid?(nil)
        refute validator.valid?({})
      end
    end

    private

    def assert_nullable_request(request)
      schema = request.to_schema(version: "2025-06").merge(
        "components" => {"schemas" => {Source.component_name => Source.to_schema(version: "2025-06")}}
      )
      params = {"value" => nil}

      assert JSONSchemer.schema(schema).valid?(params), "exported schema must accept null"
      assert request.valid_schema?(version: "2025-06")
      assert JSONSchemer.schema(request.to_validation_schema(version: "2025-06")).valid?(params)
      assert_equal params, request.process(params, version: "2025-06", validate: true)
    end

    def assert_rejects(request, value)
      assert_raises(Verquest::InvalidParamsError) do
        request.process({"value" => value}, version: "2025-06", validate: true)
      end
    end
  end
end

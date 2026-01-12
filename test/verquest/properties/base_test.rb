# frozen_string_literal: true

require "test_helper"

module Verquest
  module Properties
    class BaseTest < Minitest::Test
      def test_add_raises_no_method_error
        base = Base.new

        assert_raises(NoMethodError) do
          base.add(Field.new(name: :test, type: :string))
        end
      end

      def test_to_schema_raises_no_method_error
        base = Base.new

        assert_raises(NoMethodError) do
          base.to_schema
        end
      end

      def test_mapping_raises_no_method_error
        base = Base.new

        assert_raises(NoMethodError) do
          base.mapping(key_prefix: [], value_prefix: [], mapping: {}, version: "2025-06")
        end
      end

      def test_to_validation_schema_defaults_to_to_schema
        # Create a simple subclass that implements to_schema
        test_property = Class.new(Base) do
          def to_schema
            {"test" => {"type" => "string"}}
          end
        end.new

        assert_equal test_property.to_schema, test_property.to_validation_schema
      end
    end
  end
end

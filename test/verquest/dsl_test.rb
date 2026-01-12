# frozen_string_literal: true

require "test_helper"

module Verquest
  class DSLTest < Minitest::Test
    def test_object_without_block_raises_error
      error = assert_raises(ArgumentError) do
        Class.new(Verquest::Base) do
          version "2025-06" do
            object :test_object
          end
        end
      end

      assert_equal "a block must be given to define the object", error.message
    end

    def test_collection_without_item_and_block_raises_error
      error = assert_raises(ArgumentError) do
        Class.new(Verquest::Base) do
          version "2025-06" do
            collection :test_collection
          end
        end
      end

      assert_equal "item must be provided or a block must be given to define the collection", error.message
    end

    def test_version_inheritance
      # Test standard version inheritance
      test_class = Class.new(Verquest::Base) do
        version "2025-01" do
          field :child_field, type: :string
        end

        version "2025-06" do
          field :new_field, type: :integer
        end
      end

      schema = test_class.to_schema(version: "2025-06")

      # Standard inheritance works - v2025-06 inherits from v2025-01
      assert schema["properties"].key?("child_field")
      assert schema["properties"].key?("new_field")
    end

    def test_resolve_with_current_version_from_config
      original_current_version = Verquest.configuration.current_version

      test_class = Class.new(Verquest::Base) do
        version "2025-06" do
          field :test_field, type: :string
        end
      end

      Verquest.configuration.current_version = -> { "2025-06" }

      # Should work without providing version
      schema = test_class.to_schema

      assert schema["properties"].key?("test_field")
    ensure
      Verquest.configuration.instance_variable_set(:@current_version, original_current_version)
    end

    def test_resolve_without_version_raises_error
      original_current_version = Verquest.configuration.current_version
      Verquest.configuration.instance_variable_set(:@current_version, nil)

      test_class = Class.new(Verquest::Base) do
        version "2025-06" do
          field :test_field, type: :string
        end
      end

      error = assert_raises(ArgumentError) do
        test_class.to_schema
      end

      assert_equal "Version must be provided or set by Verquest.configuration.current_version", error.message
    ensure
      Verquest.configuration.instance_variable_set(:@current_version, original_current_version)
    end

    def test_version_not_found_error
      test_class = Class.new(Verquest::Base) do
        version "2025-06" do
          field :test_field, type: :string
        end
      end

      error = assert_raises(Verquest::VersionNotFoundError) do
        test_class.to_schema(version: "2020-01") # Version before any defined
      end

      assert_match(/Version .* not found/, error.message)
    end

    def test_validate_schema_returns_errors
      # Create a schema with an invalid structure to test validate_schema
      test_class = Class.new(Verquest::Base) do
        version "2025-06" do
          field :test_field, type: :string
        end
      end

      # A valid schema should return empty errors
      errors = test_class.send(:resolve, "2025-06").validate_schema

      assert_kind_of Array, errors
    end

    def test_validate_schema_class_method
      test_class = Class.new(Verquest::Base) do
        version "2025-06" do
          field :test_field, type: :string
        end
      end

      errors = test_class.validate_schema(version: "2025-06")

      assert_kind_of Array, errors
      assert_empty errors
    end

    def test_exclude_properties_in_version
      test_class = Class.new(Verquest::Base) do
        version "2025-01" do
          field :field_a, type: :string
          field :field_b, type: :string
          field :field_c, type: :string
        end

        version "2025-06" do
          exclude_properties :field_b, :field_c
        end
      end

      schema_v1 = test_class.to_schema(version: "2025-01")
      schema_v2 = test_class.to_schema(version: "2025-06")

      assert_equal %w[field_a field_b field_c], schema_v1["properties"].keys.sort
      assert_equal %w[field_a], schema_v2["properties"].keys
    end

    def test_exclude_properties_raises_for_nonexistent_property
      error = assert_raises(Verquest::PropertyNotFoundError) do
        Class.new(Verquest::Base) do
          version "2025-06" do
            field :field_a, type: :string
            exclude_properties :nonexistent_field
          end
        end
      end

      assert_match(/Property .* is not defined/, error.message)
    end
  end
end

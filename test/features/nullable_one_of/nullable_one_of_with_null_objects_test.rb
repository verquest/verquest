# frozen_string_literal: true

require "test_helper"

# Tests for nullable oneOf alongside nullable objects with mapping
class Verquest::NullableOneOfWithNullObjectsTest < Minitest::Test
  class TaskUpdateRequest < Verquest::Base
    description "Update Task Request"

    version "2025-09" do
      field :title, type: :string, description: "The title of the task"

      with_options nullable: true do
        field :description, type: :string, description: "Optional description"
        field :due_at, type: :string, description: "The due date"
      end

      object :site, nullable: true, description: "Site association" do
        field :id, type: :string, required: true, description: "The site ID"
      end

      object :assignee, nullable: true, map: "/extra/assigned_to" do
        field :id, type: :string, required: true, description: "The assignee ID"
      end

      one_of name: :resource, nullable: true, map: "taskable" do
        object :unit do
          field :id, type: :string, required: true, description: "The unit ID", pattern: "^unit_"
        end
        object :contact do
          field :id, type: :string, required: true, description: "The contact ID", pattern: "^con_"
        end
      end
    end
  end

  def test_process_with_all_null_values
    params = {"site" => nil, "resource" => nil, "assignee" => nil}
    expected = {"site" => nil, "extra" => {"assigned_to" => nil}, "taskable" => nil}

    result = TaskUpdateRequest.process(params, version: "2025-09")

    assert_equal expected, result
  end

  def test_process_with_title_and_all_null_values
    params = {"title" => "My Task", "site" => nil, "resource" => nil, "assignee" => nil}
    expected = {"title" => "My Task", "site" => nil, "extra" => {"assigned_to" => nil}, "taskable" => nil}

    result = TaskUpdateRequest.process(params, version: "2025-09")

    assert_equal expected, result
  end

  def test_process_with_only_mapped_nulls
    params = {"assignee" => nil, "resource" => nil}
    expected = {"extra" => {"assigned_to" => nil}, "taskable" => nil}

    result = TaskUpdateRequest.process(params, version: "2025-09")

    assert_equal expected, result
  end

  def test_process_with_mixed_null_and_values
    params = {"title" => "My Task", "site" => {"id" => "site_123"}, "resource" => nil, "assignee" => nil}
    expected = {"title" => "My Task", "site" => {"id" => "site_123"}, "extra" => {"assigned_to" => nil}, "taskable" => nil}

    result = TaskUpdateRequest.process(params, version: "2025-09")

    assert_equal expected, result
  end

  def test_process_with_valid_one_of_value
    params = {"title" => "My Task", "site" => nil, "resource" => {"id" => "unit_123"}, "assignee" => {"id" => "staff_456"}}
    expected = {"title" => "My Task", "site" => nil, "extra" => {"assigned_to" => {"id" => "staff_456"}}, "taskable" => {"id" => "unit_123"}}

    result = TaskUpdateRequest.process(params, version: "2025-09")

    assert_equal expected, result
  end

  def test_mapping_includes_nullable_target_path
    mapping = TaskUpdateRequest.mapping(version: "2025-09")

    assert mapping["_nullable"]
    assert_equal "resource", mapping["_nullable_path"]
    assert_equal "taskable", mapping["_nullable_target_path"]
  end

  def test_schema_has_source_property_names
    schema = TaskUpdateRequest.to_schema(version: "2025-09")

    assert schema["properties"].key?("site")
    assert schema["properties"].key?("assignee")
    assert schema["properties"].key?("resource")
  end

  def test_schema_does_not_have_target_property_names
    schema = TaskUpdateRequest.to_schema(version: "2025-09")

    refute schema["properties"].key?("assigned_to")
    refute schema["properties"].key?("taskable")
  end

  def test_valid_schema
    assert TaskUpdateRequest.valid_schema?(version: "2025-09")
  end
end

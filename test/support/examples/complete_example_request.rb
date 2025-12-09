# frozen_string_literal: true

require_relative "referenced_request"

class CompleteExampleRequest < Verquest::Base
  description "Example for mapping feature"

  version "2025-06" do
    # fields
    with_options required: true do
      field :field_root_string_mapped, type: :string, map: "field_root" # => field_root
      field :field_root_number_mapped_nested, type: :number, map: "nested/field_root" # => nested/field_root
      field :field_root_boolean_unmapped, type: :boolean # => field_root_boolean_unmapped
      field :field_root_integer_unmapped, type: :integer # => field_root_integer_unmapped
    end

    # objects
    object :root_object_unmapped do
      field :item_mapped, type: :string, map: "item_mapped_rename" # => root_object_unmapped/item_mapped_rename
      field :item_mapped_nested, type: :string, map: "nested/item_mapped" # => root_object_unmapped/nested/item_mapped
      field :item_unmapped, type: :string # => root_object_unmapped/item_unmapped

      # mapping outside of object (root)
      field :item_mapped_to_root, type: :string, map: "/root_object_item_outside" # => root_object_item_outside
      field :item_mapped_outside_nested, type: :string, map: "/nested/root_object_item_outside" # => nested/root_object_item_outside

      # nested object
      object :object_nested_unmapped do
        field :item_mapped, type: :string, map: "item_mapped_rename" # => root_object_unmapped/object_nested_unmapped/item_mapped_rename
        field :item_mapped_nested, type: :string, map: "nested/item_mapped" # => root_object_unmapped/object_nested_unmapped/nested/item_mapped
        field :item_unmapped, type: :string # => root_object_unmapped/object_nested_unmapped/item_unmapped

        # mapping to root
        field :item_mapped_to_root, type: :string, map: "/nested_object_item_outside" # => nested_object_item_outside
        field :item_mapped_outside_nested, type: :string, map: "/nested/nested_object_item_outside" # => nested/nested_object_item_outside

        # mapping to root_object_unmapped
        field :item_mapped_to_root_object, type: :string, map: "/root_object_unmapped/nested_object_item_outside" # => root_object_unmapped/nested_object_item_outside
      end
    end

    # objects mapped
    object :root_object_mapped, map: "root/object_mapped" do
      field :item_mapped, type: :string, map: "item_mapped_rename" # => root/object_mapped/item_mapped_rename
      field :item_mapped_nested, type: :string, map: "nested/item_mapped" # => root/object_mapped/nested/item_mapped
      field :item_unmapped, type: :string # => root/object_mapped/item_unmapped

      # nested object
      object :object_nested_unmapped, map: "object_nested_mapped" do
        field :item_mapped, type: :string, map: "item_mapped_rename" # => root/object_mapped/object_nested_mapped/item_mapped_rename
        field :item_mapped_nested, type: :string, map: "nested/item_mapped" # => root/object_mapped/object_nested_mapped/nested/item_mapped
        field :item_unmapped, type: :string # => root/object_mapped/object_nested_mapped/item_unmapped
      end

      reference :reference_mapped_to_root, from: ReferencedRequest, map: "/" # => simple/field + mapping from ReferencedRequest
      const :const_mapped_to_root, value: "const_mapped_to_root", map: "/const_mapped_to_root" # => const_mapped_to_root
    end

    # objects mapped to root
    object :root_object_mapped_to_root, map: "/" do
      field :item_mapped, type: :string, map: "item_mapped_rename_root_object_mapped_to_root" # => item_mapped_rename_root_object_mapped_to_root
      field :item_mapped_nested, type: :string, map: "nested/item_mapped_root_object_mapped_to_root" # => nested/item_mapped_root_object_mapped_to_root
      field :item_unmapped_root_object_mapped_to_root, type: :string # => item_unmapped_root_object_mapped_to_root

      collection :collection_unmapped_object_to_root, item: ReferencedRequest # => collection_unmapped_object_to_root + mapping from ReferencedRequest
    end

    # collections
    collection :collection_unmapped, item: ReferencedRequest # => collection_unmapped
    collection :collection_mapped, item: ReferencedRequest, map: "collection_mapped_somewhere" # => # collection_mapped_somewhere

    # collection with fields
    collection :collection_with_fields do
      field :item_mapped, type: :string, map: "item_mapped_collection" # => collection_with_fields/item_mapped_collection
      field :item_mapped_nested, type: :string, map: "nested/item_mapped_nested" # => collection_with_fields/nested/item_mapped_nested
      field :item_unmapped, type: :string # => collection_with_fields/item_unmapped
    end

    object :collection_in_object do
      collection :collection_unmapped, item: ReferencedRequest # => collection_in_object/collection_unmapped
    end

    # arrays
    array :array_unmapped, type: :string, item_schema_options: {format: "uuid"} # => array_unmapped
    array :array_mapped, type: :number, map: "rename_array_mapped" # => rename_array_mapped

    # references
    reference :reference_unmapped, from: ReferencedRequest # => reference_unmapped + mapping from ReferencedRequest
    reference :reference_mapped_to_root, from: ReferencedRequest, map: "referenced" # => referenced/simple/field
    reference :reference_unmapped_with_property, from: ReferencedRequest, property: :simple_field  # => reference_unmapped_with_property
    reference :reference_mapped_with_property, from: ReferencedRequest, map: "referenced_with_property", property: :simple_field # => referenced_with_property

    # const
    const :const_unmapped, value: 1 # => const_unmapped
    const :const_mapped, value: true, map: "const/mapped" # => const/mapped

    # enums
    enum :enum_unmapped, values: %w[one two three] # => enum_unmapped
    enum :enum_mapped, values: [1, "a", 2, "b"], nullable: true, map: "enum/mapped" # => enum/mapped
  end
end

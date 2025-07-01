# frozen_string_literal: true

require_relative "referenced_request"

class NullableRequest < Verquest::Base
  description "This is a simple request with nullable properties for testing purposes."

  version "2025-06" do
    with_options nullable: true do
      array :array, type: :string
      collection :collection_with_item, item: ReferencedRequest
      collection :collection_with_object do
        field :field, type: :string, nullable: false
      end

      field :field, type: :string

      object :object do
        field :field, type: :string, nullable: false
      end

      reference :referenced_object, from: ReferencedRequest
      reference :referenced_field, from: ReferencedRequest, property: :simple_field
    end
  end
end

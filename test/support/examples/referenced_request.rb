# frozen_string_literal: true

class ReferencedRequest < Verquest::Base
  version "2025-06" do
    description "This is an another example for testing purposes."

    with_options required: true, type: :string do
      field :simple_field, map: "simple.field", description: "The simple field"

      object :nested do
        field :nested_field_1, required: false, map: "field_1", description: "This is a nested field"
        field :nested_field_2, type: :number, map: "field_2", description: "This is another nested field"
      end
    end
  end
end

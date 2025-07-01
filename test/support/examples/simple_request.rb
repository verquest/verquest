# frozen_string_literal: true

class SimpleRequest < Verquest::Base
  description "This is a simple request for testing purposes."
  schema_options additional_properties: true

  version "2025-06" do
    field :email, type: :string, required: true, format: "email"
    field :name, type: :string

    object :address, additional_properties: true do
      field :street, type: :string, map: "/address_street"
      field :city, type: :string, required: true, map: "/address_city"
      field :zip_code, type: :string, map: "/address_zip_code"
    end
  end

  version "2025-08", exclude_properties: %i[name] do
    schema_options additional_properties: nil

    field :name, type: :string, required: true, min_length: 3, max_length: 50
  end
end

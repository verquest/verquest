# frozen_string_literal: true

require "test_helper"

# Tests references to a single property that is not a scalar
class Verquest::ReferenceToPropertyTest < Minitest::Test
  class AddressComponent < Verquest::Base
    version "2025-06" do
      field :id, type: :string

      object :home do
        field :street, type: :string, map: "line1"
        field :city, type: :string
      end

      collection :tags do
        field :label, type: :string
      end

      one_of name: :contact, discriminator: :type do
        object :email do
          const :type, value: "email"
          field :address, type: :string
        end

        object :phone do
          const :type, value: "phone"
          field :number, type: :string, map: "digits"
        end
      end
    end
  end

  class PersonRequest < Verquest::Base
    version "2025-06" do
      field :name, type: :string, required: true
      reference :address, from: AddressComponent, property: :home
      reference :labels, from: AddressComponent, property: :tags, map: "keywords"
      reference :reach, from: AddressComponent, property: :contact
      reference :key, from: AddressComponent, property: :id, map: "/address_id"
    end
  end

  def test_process
    params = {
      "name" => "Ann",
      "address" => {"street" => "Main", "city" => "Prague"},
      "labels" => [{"label" => "a"}],
      "reach" => {"type" => "phone", "number" => "123"},
      "key" => "k1"
    }

    expected = {
      "name" => "Ann",
      "address" => {"line1" => "Main", "city" => "Prague"},
      "keywords" => [{"label" => "a"}],
      "reach" => {"type" => "phone", "digits" => "123"},
      "address_id" => "k1"
    }

    assert_equal expected, PersonRequest.process(params, version: "2025-06")
  end

  def test_unknown_property_raises
    error = assert_raises(Verquest::PropertyNotFoundError) do
      Class.new(Verquest::Base) do
        version("2025-06") { reference :address, from: AddressComponent, property: :missing }
      end
    end

    assert_match "Property 'missing'", error.message
  end
end

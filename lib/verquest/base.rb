# frozen_string_literal: true

module Verquest
  # Base class for API request definition and mapping
  #
  # This class is the foundation of the Verquest versioning system. Classes that inherit from Base
  # can define their request structure using the versioning DSL, including fields, objects,
  # collections, and references. The Base class handles parameter mapping, schema generation,
  # and validation based on version specifications.
  #
  # @example Define a versioned API request class
  #   class UserCreateRequest < Verquest::Base
  #     description "User Create Request"
  #     schema_options additional_properties: false
  #
  #     version "2025-06" do
  #       field :email, type: :string, required: true, format: "email"
  #       field :name, type: :string
  #
  #       object :address do
  #         field :street, type: :string, map: "/address_street"
  #         field :city, type: :string, required: true, map: "/address_city"
  #         field :zip_code, type: :string, map: "/address_zip_code"
  #       end
  #     end
  #
  #     version "2025-08", exclude_properties: %i[name] do
  #       field :name, type: :string, required: true
  #     end
  #   end
  #
  # @see Verquest::Base::PublicClassMethods for available class methods
  class Base
    extend Base::HelperClassMethods
    extend Base::PrivateClassMethods
    extend Base::PublicClassMethods
  end
end

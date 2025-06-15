# frozen_string_literal: true

module Verquest
  # Property types for defining versioned API request schemas
  #
  # The Properties module contains classes representing different types of
  # properties that can be used when defining API request schemas. Each property
  # type knows how to generate its own schema representation and handles mapping
  # between external and internal parameter structures.
  #
  # @example Using properties in a schema definition
  #   class UserRequest < Verquest::Base
  #     version "2023-01" do
  #       # Field - Basic scalar properties
  #       field :email, type: :string, required: true
  #
  #       # Object - Nested structure with properties
  #       object :address do
  #         field :street, type: :string
  #         field :city, type: :string, required: true
  #       end
  #
  #       # Collection - Array of objects
  #       collection :orders do
  #         field :id, type: :string, required: true
  #         field :amount, type: :number
  #       end
  #
  #       # Array - Simple array of scalar values
  #       array :tags, type: :string
  #
  #       # Reference - Reference to another schema
  #       reference :payment, from: PaymentRequest
  #     end
  #   end
  #
  # @see Verquest::Properties::Base Base class for all property types
  # @see Verquest::Properties::Field For scalar values like strings and numbers
  # @see Verquest::Properties::Object For nested objects with their own properties
  # @see Verquest::Properties::Collection For arrays of structured objects
  # @see Verquest::Properties::Array For arrays of scalar values
  # @see Verquest::Properties::Reference For references to other schemas
  module Properties
    # This module is a namespace for property type classes
    # Each property type is defined in its own file under lib/verquest/properties/
  end
end

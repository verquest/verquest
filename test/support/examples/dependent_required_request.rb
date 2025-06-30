# frozen_string_literal: true

class DependentRequiredRequest < Verquest::Base
  description "This is a simple request with nullable properties for testing purposes."

  version "2025-06" do
    field :name, type: :string, required: true
    field :credit_card, type: :number, required: %i[billing_address]
    field :billing_address, type: :string
  end
end

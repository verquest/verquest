# frozen_string_literal: true

class CardPaymentComponent < Verquest::Base
  version "2025-06" do
    const :method, value: "card", required: true
    field :card_number, type: :string, required: true
    field :expiry, type: :string, required: true
    field :cvv, type: :string
  end
end

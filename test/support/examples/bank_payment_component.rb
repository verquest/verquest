# frozen_string_literal: true

class BankPaymentComponent < Verquest::Base
  version "2025-06" do
    const :method, value: "bank", required: true
    field :account_number, type: :string, required: true
    field :routing_number, type: :string, required: true
  end
end

# frozen_string_literal: true

require_relative "card_payment_component"
require_relative "bank_payment_component"

class OrderRequest < Verquest::Base
  version "2025-06" do
    field :order_id, type: :string, required: true
    field :amount, type: :number, required: true

    one_of name: :payment, discriminator: :method, required: true do
      reference :card, from: CardPaymentComponent
      reference :bank, from: BankPaymentComponent
    end
  end
end

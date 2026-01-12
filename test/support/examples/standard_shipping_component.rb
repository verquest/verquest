# frozen_string_literal: true

class StandardShippingComponent < Verquest::Base
  version "2025-06" do
    field :type, type: :string, required: true
    field :carrier, type: :string, required: true
    field :tracking_number, type: :string
  end
end

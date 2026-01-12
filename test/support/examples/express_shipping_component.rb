# frozen_string_literal: true

class ExpressShippingComponent < Verquest::Base
  version "2025-06" do
    field :type, type: :string, required: true
    field :service, type: :string, required: true
    field :delivery_date, type: :string, required: true
  end
end

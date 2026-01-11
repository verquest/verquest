# frozen_string_literal: true

class WithIdComponent < Verquest::Base
  version "2025-06" do
    field :id, type: :string, required: true
    field :name, type: :string, required: true
    field :value, type: :integer
  end
end

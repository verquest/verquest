# frozen_string_literal: true

class WithoutIdComponent < Verquest::Base
  version "2025-06" do
    field :name, type: :string, required: true
    field :description, type: :string, required: true
  end
end

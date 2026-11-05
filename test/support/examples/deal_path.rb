class DealPath < Verquest::Base
  location :path

  version "2025-06" do
    field :id, type: :string, required: true, pattern: "^deal_", description: "The ID of the deal",
      parameter_examples: {deal: {value: "deal_0123456789abcdef"}}
  end
end

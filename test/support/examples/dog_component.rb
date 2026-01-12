class DogComponent < Verquest::Base
  version "2025-06" do
    const :type, value: "dog", required: true
    field :name, type: :string, required: true
    field :bark, type: :boolean
  end
end

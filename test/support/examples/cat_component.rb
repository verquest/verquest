class CatComponent < Verquest::Base
  version "2025-06" do
    const :type, value: "cat", required: true
    field :name, type: :string, required: true
    field :meow, type: :boolean
  end
end

class ExpandQuery < Verquest::Base
  location :query

  version "2025-06" do
    array :expand, type: :string, explode: false, description: "Related resources to expand"
  end
end

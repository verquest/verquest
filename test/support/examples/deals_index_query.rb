class DealsIndexQuery < Verquest::Base
  location :query

  version "2025-06" do
    field :page, type: :integer
    filter :status, as: :array, type: :string, explode: false do |deals, value|
      deals.select { |deal| value.include?(deal[:status]) }
    end
  end

  version "2025-08" do
    filter :site_id, type: :string do |deals, value|
      deals.select { |deal| deal[:site_id] == value }
    end
  end
end

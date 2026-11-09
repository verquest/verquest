class DealsIndexQuery < Verquest::Base
  location :query

  version "2025-06" do
    field :page, type: :integer, minimum: 1, default: 1
    field :archived, type: :boolean
    enum :sort_direction, values: %w[ASC DESC], default: "DESC"
    filter :status, as: :array, type: :string, explode: false, item_schema_options: {enum: %w[open won lost]} do |deals, value|
      deals.select { |deal| value.include?(deal[:status]) }
    end

    object :created do
      field :after, type: :string, format: "date-time", map: "/created_after"
    end
  end

  version "2025-08" do
    filter :site_id, type: :string do |deals, value|
      deals.select { |deal| deal[:site_id] == value }
    end
  end
end

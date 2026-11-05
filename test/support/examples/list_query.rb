require_relative "expand_query"

class ListQuery < Verquest::Base
  location :query

  version "2025-06" do
    reference :expand, from: ExpandQuery, property: :expand
    field :page, type: :integer, minimum: 1, default: 1
    field :archived, type: :boolean, parameter_examples: {archived: {value: true}}
    enum :sort_direction, values: %w[ASC DESC], default: "DESC"
    array :status, type: :string, explode: false, item_schema_options: {enum: %w[open won lost]},
      parameter_examples: {single: {value: %w[open]}, multiple: {value: %w[open won]}}
    array :site_id, type: :string, explode: true, map: "site_ids"
    object :created do
      field :after, type: :string, format: "date-time", map: "/created_after"
    end
  end

  version "2025-08" do
    field :search, type: :string
  end
end

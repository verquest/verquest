# frozen_string_literal: true

module Verquest
  # Support for query and path requests (`location :query`, `location :path`)
  #
  # Query strings and paths carry only strings and flat keys, so these versions
  # convert their params before validating them ({Query::Coercer}), reject
  # shapes their location can't express ({Query::DefinitionCheck}), and
  # document their properties as OpenAPI parameters ({Query::Parameters}).
  #
  # @example
  #   class ListQuery < Verquest::Base
  #     location :query
  #
  #     version "2025-06" do
  #       field :page, type: :integer
  #       array :status, type: :string, explode: false
  #     end
  #   end
  #
  #   ListQuery.process({"page" => "2", "status" => "open,won"}, version: "2025-06")
  #   # => {"page" => 2, "status" => ["open", "won"]}
  module Query
  end
end

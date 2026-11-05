# frozen_string_literal: true

module Verquest
  # Support for query requests (`location :query`)
  #
  # Query strings carry only strings and flat keys, so a query version converts
  # its params before validating them ({Query::Coercer}), rejects shapes a query
  # string can't express ({Query::DefinitionCheck}), and documents its
  # properties as OpenAPI parameters ({Query::Parameters}).
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

# frozen_string_literal: true

module Verquest
  class Transformer
    # A collection whose items are transformed one by one, because they hold a oneOf
    #
    # @!attribute [r] source
    #   @return [Path] The collection in the params
    # @!attribute [r] target
    #   @return [Path] The collection in the result
    # @!attribute [r] scope
    #   @return [Scope] The mapping of each item, with item-level paths
    Collection = Data.define(:source, :target, :scope) do
      # Transforms the collection items into the result
      #
      # A null collection, or one below a null parent, stays null.
      #
      # @param params [Hash] The input parameters
      # @param result [Hash] The hash to write to
      # @return [Hash] The result
      # @raise [Verquest::MappingError] If an item's oneOf matches no variant or more than one
      def call(params, result)
        items = source.extract(params, nulls: true)
        return result if items.equal?(Path::NOT_FOUND)

        target.set(result, items.is_a?(Array) ? items.map { |item| scope.call(item) } : items)
      end
    end
  end
end

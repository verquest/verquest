# frozen_string_literal: true

module Verquest
  class Transformer
    # A collection whose items are transformed one by one, because they hold a oneOf
    #
    # @!attribute [r] source
    #   @return [Path] The collection in the data of the parent scope
    # @!attribute [r] target
    #   @return [Path] The collection in the result of the parent scope
    # @!attribute [r] scope
    #   @return [Scope] The mapping of each item, with item-level paths
    Collection = Data.define(:source, :target, :scope) do
      # Transforms the collection items into the result
      #
      # A null collection, or one below a null parent, stays null.
      #
      # @param data [Object] The data of the parent scope
      # @param result [Hash] The result of the parent scope
      # @return [Hash] The result
      # @raise [Verquest::MappingError] If an item's oneOf matches no variant or more than one
      def call(data, result)
        items = source.extract(data, nulls: true)
        return result if items.equal?(Path::NOT_FOUND)

        target.set(result, items.is_a?(Array) ? items.map { |item| scope.call(item) } : items)
      end
    end
  end
end

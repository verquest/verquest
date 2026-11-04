# frozen_string_literal: true

module Verquest
  class Transformer
    # The mapping of the params, or of one collection item
    #
    # When a source path's parent is explicitly null, the corresponding target
    # path is set to null in the result instead of being omitted.
    #
    # Collections whose items hold a oneOf get their own scope for each item,
    # since every item can select a different variant. Those scopes can hold
    # collections again.
    #
    # @!attribute [r] pairs
    #   @return [Array<Array(Path, Path)>] The source and target pairs mapped for any input
    # @!attribute [r] one_ofs
    #   @return [Array<OneOf>] The oneOfs that add the pairs of the variant each input selects
    # @!attribute [r] collections
    #   @return [Array<Collection>] The collections transformed item by item
    Scope = Data.define(:pairs, :one_ofs, :collections) do
      # Transforms the data
      #
      # @param data [Object] The params or a collection item
      # @return [Hash] The transformed data
      # @raise [Verquest::MappingError] If a oneOf matches no variant or more than one
      def call(data)
        result = {}
        map(pairs, data, result)
        one_ofs.each { |one_of| map(one_of.mapping_for(data), data, result) }
        collections.each { |collection| collection.call(data, result) }
        result
      end

      private

      # Copies the value of each source path to its target path
      #
      # @param pairs [Array<Array(Path, Path)>] The source and target pairs
      # @param data [Object] The data to read from
      # @param result [Hash] The hash to write to
      # @return [void]
      def map(pairs, data, result)
        pairs.each do |source, target|
          value = source.extract(data, nulls: true)
          target.set(result, value) unless value.equal?(Path::NOT_FOUND)
        end
      end
    end
  end
end

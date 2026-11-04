# frozen_string_literal: true

module Verquest
  # Compares the transformer built from properties with the one built from
  # the mapping, on every params a test maps. Enabled with COMPARE_PLANS=1.
  # Versions with a oneOf inside a oneOf variant are skipped: the mapping
  # can't express them, so only the property-built transformer maps them.
  # Remove it with Transformer.new(mapping:) in 1.0.0.
  module PlanComparison
    # Raised when the two transformers return different results
    class Mismatch < StandardError; end

    def self.transformers
      @transformers ||= {}
    end

    def map_params(params)
      return super if one_of_inside_variant?

      from_properties = outcome { transformer.call(params) }
      from_mapping = outcome { mapping_transformer.call(params) }
      raise Mismatch, "Version '#{name}': properties #{from_properties.inspect}, mapping #{from_mapping.inspect}" unless from_properties == from_mapping

      super
    end

    private

    def mapping_transformer
      PlanComparison.transformers[object_id] ||= begin
        # A root-level oneOf's discriminator isn't in the mapping (formerly Version#combination_discriminator)
        discriminator = properties.values.first.send(:discriminator) if combination?
        DeprecationHelper.without_deprecation_warnings { Transformer.new(mapping:, discriminator:) }
      end
    end

    def one_of_inside_variant?
      PlanComparison.transformers.fetch([object_id, :nested]) do |key|
        PlanComparison.transformers[key] = nested_one_of?(transformer_layout.one_ofs)
      end
    end

    # Every oneOf below a variant sits in that variant's own one_ofs, so the
    # top-level variants tell whether any oneOf is nested, at any depth
    def nested_one_of?(one_ofs)
      one_ofs.any? { |one_of| one_of.variants.each_value.any? { |variant| variant.one_ofs.any? } }
    end

    def outcome
      {result: yield}
    rescue MappingError => e
      {error: e.message}
    end
  end
end

Verquest::Version.prepend(Verquest::PlanComparison)

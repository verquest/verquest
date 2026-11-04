# frozen_string_literal: true

require "test_helper"

module Verquest
  module Properties
    # Tests the layout properties add for the transformer
    class LayoutTest < Minitest::Test
      class PaymentComponent < Verquest::Base
        version "2025-06" do
          field :amount, type: :number

          one_of name: :method, discriminator: :type, nullable: true, map: "pay" do
            object :card do
              const :type, value: "card"
              field :number, type: :string, map: "digits"
            end
          end
        end
      end

      class OrderRequest < Verquest::Base
        version "2025-06" do
          field :id, type: :string, map: "/ident"
          object(:user) { field :first, type: :string, map: "first_name" }
          reference :payment, from: PaymentComponent, map: "billing"

          collection :pets, map: "animals" do
            one_of discriminator: :type do
              object :dog do
                const :type, value: "dog"
                field :bark, type: :boolean, map: "woof"
              end
            end
          end
        end
      end

      class OwnerComponent < Verquest::Base
        version "2025-06" do
          const :kind, value: "owner"

          collection :pets, map: "animals" do
            one_of discriminator: :type do
              object :dog do
                const :type, value: "dog"
                field :bark, type: :boolean, map: "woof"
              end
            end
          end
        end
      end

      class PartyRequest < Verquest::Base
        version "2025-06" do
          one_of name: :party, discriminator: :kind do
            reference :owner, from: OwnerComponent

            object :guest do
              const :kind, value: "guest"
            end
          end
        end
      end

      def test_layout
        layout = Verquest::Transformer::Layout.new
        OrderRequest.resolve("2025-06").all_properties.each_value do |property|
          property.layout(key_prefix: [], value_prefix: [], layout:, version: "2025-06")
        end
        one_ofs = layout.one_ofs.map { |one_of| one_of_hash(one_of) }

        expected = {
          pairs: {"id" => "ident", "user/first" => "user/first_name", "payment/amount" => "billing/amount"},
          collections: {"pets[]" => "animals[]"},
          one_ofs: [
            {
              path: "payment/method", discriminator: "payment/method/type", null_target: "billing/pay",
              variants: {"card" => {"payment/method/type" => "billing/pay/type", "payment/method/number" => "billing/pay/digits"}}
            },
            {
              path: "pets[]", discriminator: "pets[]/type", null_target: nil,
              variants: {"dog" => {"pets[]/type" => "animals[]/type", "pets[]/bark" => "animals[]/woof"}}
            }
          ]
        }

        assert_equal expected, {pairs: layout.pairs, collections: layout.collections, one_ofs:}
      end

      def test_layout_of_a_oneof_and_a_collection_inside_a_reference_variant
        layout = Verquest::Transformer::Layout.new
        PartyRequest.resolve("2025-06").all_properties.each_value do |property|
          property.layout(key_prefix: [], value_prefix: [], layout:, version: "2025-06")
        end
        party = layout.one_ofs.first
        owner = party.variants["owner"]

        expected = {
          collections: {},
          owner_collections: {"party/pets[]" => "party/animals[]"},
          party: {path: "party", discriminator: "party/kind", null_target: nil, variants: %w[owner guest]},
          owner_pairs: {"party/kind" => "party/kind"},
          owner_one_ofs: [
            {
              path: "party/pets[]", discriminator: "party/pets[]/type", null_target: nil,
              variants: {"dog" => {"party/pets[]/type" => "party/animals[]/type", "party/pets[]/bark" => "party/animals[]/woof"}}
            }
          ]
        }

        assert_equal expected, {
          collections: layout.collections,
          owner_collections: owner.collections,
          party: party.to_h.except(:variant_schemas).merge(variants: party.variants.keys),
          owner_pairs: owner.pairs,
          owner_one_ofs: owner.one_ofs.map { |one_of| one_of_hash(one_of) }
        }
      end

      private

      # Every oneOf here has a discriminator, so variant_schemas is nil
      def one_of_hash(one_of)
        one_of.to_h.except(:variant_schemas).merge(variants: one_of.variants.transform_values(&:pairs))
      end
    end
  end
end

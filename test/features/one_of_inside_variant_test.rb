# frozen_string_literal: true

require "test_helper"

# Tests oneOfs and collections inside oneOf variants
class Verquest::OneOfInsideVariantTest < Minitest::Test
  class PetComponent < Verquest::Base
    version "2025-06" do
      one_of name: :pet, discriminator: :type do
        object :dog do
          const :type, value: "dog"
          field :bark, type: :boolean, map: "woof"
        end

        object :cat do
          const :type, value: "cat"
        end
      end
    end
  end

  class OwnerRequest < Verquest::Base
    version "2025-06" do
      one_of name: :owner do
        object :person do
          field :name, type: :string, required: true

          one_of name: :pet, discriminator: :type do
            object :dog do
              const :type, value: "dog"
              field :bark, type: :boolean, map: "woof"
            end

            object :cat do
              const :type, value: "cat"
            end
          end
        end

        object :company do
          field :vat, type: :string, required: true

          collection :contacts do
            one_of name: :channel, discriminator: :type do
              object :email do
                const :type, value: "email"
                field :address, type: :string, map: "to"
              end

              object :phone do
                const :type, value: "phone"
                field :number, type: :string
              end
            end
          end
        end

        reference :animal_owner, from: PetComponent
      end
    end
  end

  class ShelterRequest < Verquest::Base
    version "2025-06" do
      one_of name: :pet, discriminator: :type do
        object :dog do
          const :type, value: "dog"

          collection :items, map: "dog_items" do
            one_of name: :thing, discriminator: :kind do
              object :ball do
                const :kind, value: "ball"
                field :size, type: :integer
              end
            end
          end
        end

        object :cat do
          const :type, value: "cat"

          collection :items, map: "cat_items" do
            one_of name: :thing, discriminator: :kind do
              object :ball do
                const :kind, value: "ball"
                field :size, type: :integer
              end
            end
          end
        end
      end
    end
  end

  def test_process
    cases = {
      "inline variant with a oneOf" => [
        {"owner" => {"name" => "A", "pet" => {"type" => "dog", "bark" => true}}},
        {"owner" => {"name" => "A", "pet" => {"type" => "dog", "woof" => true}}}
      ],
      "inline variant with a collection of oneOfs" => [
        {"owner" => {"vat" => "1", "contacts" => [{"channel" => {"type" => "email", "address" => "a@b.c"}}, {"channel" => {"type" => "phone", "number" => "1"}}]}},
        {"owner" => {"vat" => "1", "contacts" => [{"channel" => {"type" => "email", "to" => "a@b.c"}}, {"channel" => {"type" => "phone", "number" => "1"}}]}}
      ],
      "reference variant with a oneOf" => [
        {"owner" => {"pet" => {"type" => "dog", "bark" => false}}},
        {"owner" => {"pet" => {"type" => "dog", "woof" => false}}}
      ]
    }

    results = cases.transform_values { |(params, _)| OwnerRequest.process(params, version: "2025-06") }

    assert_equal cases.transform_values(&:last), results
  end

  def test_mapping_and_external_mapping
    pet = {"_discriminator" => "owner/pet/type"}
    channel = {"_discriminator" => "owner/contacts[]/channel/type"}
    pet_mapping = pet.merge(
      "dog" => {"owner/pet/type" => "owner/pet/type", "owner/pet/bark" => "owner/pet/woof"},
      "cat" => {"owner/pet/type" => "owner/pet/type"}
    )
    pet_external_mapping = pet.merge(
      "dog" => {"owner/pet/type" => "owner/pet/type", "owner/pet/woof" => "owner/pet/bark"},
      "cat" => {"owner/pet/type" => "owner/pet/type"}
    )
    channel_mapping = channel.merge(
      "email" => {"owner/contacts[]/channel/type" => "owner/contacts[]/channel/type", "owner/contacts[]/channel/address" => "owner/contacts[]/channel/to"},
      "phone" => {"owner/contacts[]/channel/type" => "owner/contacts[]/channel/type", "owner/contacts[]/channel/number" => "owner/contacts[]/channel/number"}
    )
    channel_external_mapping = channel.merge(
      "email" => {"owner/contacts[]/channel/type" => "owner/contacts[]/channel/type", "owner/contacts[]/channel/to" => "owner/contacts[]/channel/address"},
      "phone" => {"owner/contacts[]/channel/type" => "owner/contacts[]/channel/type", "owner/contacts[]/channel/number" => "owner/contacts[]/channel/number"}
    )
    expected = {
      mapping: {
        "person" => {"owner/name" => "owner/name", "_oneOfs" => [pet_mapping]},
        "company" => {"owner/vat" => "owner/vat", "_oneOfs" => [channel_mapping]},
        "animal_owner" => {"_oneOfs" => [pet_mapping]}
      },
      external_mapping: {
        "person" => {"owner/name" => "owner/name", "_oneOfs" => [pet_external_mapping]},
        "company" => {"owner/vat" => "owner/vat", "_oneOfs" => [channel_external_mapping]},
        "animal_owner" => {"_oneOfs" => [pet_external_mapping]}
      }
    }

    # The top-level _variant_path and _variant_schemas are left out for brevity
    variants = %w[person company animal_owner]
    actual = {
      mapping: OwnerRequest.mapping(version: "2025-06").slice(*variants),
      external_mapping: OwnerRequest.external_mapping(version: "2025-06").slice(*variants)
    }

    assert_equal expected, actual
  end

  def test_same_named_collections_in_variants_keep_their_targets
    items = [{"thing" => {"kind" => "ball", "size" => 1}}]
    results = %w[dog cat].to_h { |type| [type, ShelterRequest.process({"pet" => {"type" => type, "items" => items}}, version: "2025-06")] }

    expected = {
      "dog" => {"pet" => {"type" => "dog", "dog_items" => items}},
      "cat" => {"pet" => {"type" => "cat", "cat_items" => items}}
    }

    assert_equal expected, results
  end
end

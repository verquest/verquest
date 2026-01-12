# frozen_string_literal: true

require_relative "cat_component"
require_relative "dog_component"

class PetRequest < Verquest::Base
  version "2025-06" do
    description "oneOf example"

    one_of discriminator: :type do
      reference :dog, from: DogComponent
      reference :cat, from: CatComponent
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module Verquest
  module Properties
    class OneOf
      class DiscriminatedSchemaTest < Minitest::Test
        DEFINITIONS = {"dog" => {"type" => "object"}, "cat" => {"type" => "object"}}.freeze

        def test_to_h
          expected = {
            "definitions" => DEFINITIONS,
            "oneOf" => [{"$ref" => "#/definitions/dog"}, {"$ref" => "#/definitions/cat"}],
            "discriminator" => {"propertyName" => "type", "mapping" => {"dog" => "#/definitions/dog", "cat" => "#/definitions/cat"}}
          }

          schema = DiscriminatedSchema.new(definitions: DEFINITIONS, discriminator: "type").to_h

          assert_equal %w[$id id definitions oneOf discriminator], schema.keys
          assert_equal expected, schema.except("$id", "id")
        end

        def test_id_and_legacy_id_are_the_same_content_hash
          schema = DiscriminatedSchema.new(definitions: DEFINITIONS, discriminator: "type").to_h

          assert_match %r{\Ahttps://verquest\.local/one_of/\h{16}\z}, schema["$id"]
          assert_equal schema["$id"], schema["id"]
        end

        def test_id_depends_only_on_content
          first_id = DiscriminatedSchema.new(definitions: DEFINITIONS, discriminator: "type").to_h["$id"]
          same_content_id = DiscriminatedSchema.new(definitions: DEFINITIONS.dup, discriminator: "type").to_h["$id"]
          other_content_id = DiscriminatedSchema.new(definitions: DEFINITIONS, discriminator: "kind").to_h["$id"]

          assert_equal first_id, same_content_id
          refute_equal first_id, other_content_id
        end

        def test_id_supports_infinite_numbers
          definitions = {"dog" => {"type" => "number", "maximum" => Float::INFINITY}}

          schema = DiscriminatedSchema.new(definitions: definitions, discriminator: "type").to_h

          assert_match %r{\Ahttps://verquest\.local/one_of/\h{16}\z}, schema["$id"]
        end
      end
    end
  end
end

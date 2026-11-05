# frozen_string_literal: true

require "test_helper"

# References and collection items whose class is not a Verquest::Base, only implementing
# the reference protocol (to_ref and to_validation_schema), as versponse responses do
class Verquest::SchemaOnlyReferenceTest < Minitest::Test
  class ExternalComponent
    SCHEMA = {
      "type" => "object",
      "required" => ["id"],
      "properties" => {"id" => {"type" => "string"}},
      "additionalProperties" => false
    }.freeze

    def self.to_ref(property: nil)
      base = "#/components/schemas/External"
      property ? "#{base}/properties/#{property}" : base
    end

    def self.to_validation_schema(version:, property: nil)
      property ? SCHEMA["properties"].fetch(property.to_s) : SCHEMA
    end
  end

  class OrderRequest < Verquest::Base
    version "2025-06" do
      field :note, type: :string
      reference :external, from: ExternalComponent, map: "ext"
      collection :externals, item: ExternalComponent
    end
  end

  def test_schema_uses_refs
    properties = OrderRequest.to_schema(version: "2025-06")["properties"]

    assert_equal({"$ref" => "#/components/schemas/External"}, properties["external"])
    assert_equal({"$ref" => "#/components/schemas/External"}, properties["externals"]["items"])
  end

  def test_validation_schema_inlines_the_external_schema
    properties = OrderRequest.to_validation_schema(version: "2025-06")["properties"]

    assert_equal ExternalComponent::SCHEMA, properties["external"]
    assert_equal ExternalComponent::SCHEMA, properties["externals"]["items"]
  end

  def test_values_pass_through_mapping
    params = {"note" => "n", "external" => {"id" => "e1"}, "externals" => [{"id" => "e2"}]}

    assert_equal({"note" => "n", "ext" => {"id" => "e1"}, "externals" => [{"id" => "e2"}]}, OrderRequest.process(params, version: "2025-06"))
  end

  def test_invalid_values_fail_validation
    params = {"note" => "n", "external" => {"id" => 1}, "externals" => []}

    error = assert_raises(Verquest::InvalidParamsError) { OrderRequest.process(params, version: "2025-06") }

    assert_equal "/external/id", error.errors.first[:pointer]
  end

  def test_one_of_variants_must_be_verquest_requests
    error = assert_raises(ArgumentError) do
      Class.new(Verquest::Base) do
        version("2025-06") { one_of(name: :thing) { reference :a, from: ExternalComponent } }
      end
    end

    assert_match(/one_of variants must reference Verquest::Base subclasses/, error.message)
  end

  def test_collection_item_must_respond_to_to_ref
    error = assert_raises(ArgumentError) do
      Class.new(Verquest::Base) do
        version("2025-06") { collection :things, item: Object }
      end
    end

    assert_match(/item must be a Verquest::Base subclass or respond to to_ref/, error.message)
  end

  def test_query_parameter_from_schema_only_reference
    query = Class.new(Verquest::Base) do
      location :query

      version("2025-06") { reference :external, from: ExternalComponent }
    end

    parameter = query.to_parameters(version: "2025-06").first

    assert_equal "external", parameter[:name]
    assert_equal JSON.parse(ExternalComponent::SCHEMA.to_json, symbolize_names: true), parameter[:schema]
  end
end

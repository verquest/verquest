# frozen_string_literal: true

require "test_helper"

class Verquest::SupportedVersionsRangeTest < Minitest::Test
  include Verquest::ConfigurationTestHelper

  # Orders "v9" before "v10", unlike string comparison
  NUMERIC = lambda do |requested, versions|
    number = ->(name) { name.delete_prefix("v").to_i }
    versions.select { |name| number.call(name) <= number.call(requested) }.max_by(&number)
  end

  class BaseRequest < Verquest::Base
    supported_versions max: "2025-09"
  end

  class OverlockRequest < BaseRequest
    version "2025-06" do
      field :reason, type: :string
    end
  end

  class OpenRequest < BaseRequest
    supported_versions

    version "2025-06" do
      field :reason, type: :string
    end
  end

  # Appears only from "preview", served by its single 2025-09 block
  class PreviewRequest < Verquest::Base
    supported_versions min: "preview"

    version "2025-09" do
      field :name, type: :string
    end
  end

  def test_subclasses_inherit_and_override_the_range
    assert_equal "2025-09", OverlockRequest.supported_version_range.max
    assert_nil OpenRequest.supported_version_range
    assert_equal "preview", PreviewRequest.supported_version_range.min
  end

  def test_subclass_of_a_subclass_inherits_the_range
    request = Class.new(OverlockRequest) do
      version("2025-06") { field :note, type: :string }
    end

    assert_equal ["note"], request.to_schema(version: "2025-09")["properties"].keys
    assert_raises(Verquest::VersionNotFoundError) { request.to_schema(version: "2026-01") }
  end

  def test_min_after_max_raises
    assert_raises(Verquest::DefinitionError) { Class.new(Verquest::Base) { supported_versions min: "preview", max: "2025-09" } }
  end

  def test_declaring_after_the_first_version_raises
    error = assert_raises(Verquest::DefinitionError) do
      Class.new(Verquest::Base) do
        version("2025-06") { field :reason, type: :string }
        supported_versions max: "2025-09"
      end
    end

    assert_includes error.message, "must be set before the first version"
  end

  def test_versions_inside_the_range_resolve
    assert_equal ["reason"], OverlockRequest.to_schema(version: "2025-06")["properties"].keys
    assert_equal({"reason" => "x"}, OverlockRequest.process({"reason" => "x"}, version: "2025-09"))
  end

  def test_versions_outside_the_range_raise
    error = assert_raises(Verquest::VersionNotFoundError) { OverlockRequest.process({"reason" => "x"}, version: "2026-01") }

    assert_equal "Version '2026-01' is outside supported_versions (min: first declared, max: 2025-09) of Verquest::SupportedVersionsRangeTest::OverlockRequest", error.message
    assert_raises(Verquest::VersionNotFoundError) { OverlockRequest.to_validation_schema(version: "2025-10") }
  end

  def test_min_defaults_to_the_first_declared_version
    assert_raises(Verquest::VersionNotFoundError) { OverlockRequest.to_schema(version: "2025-01") }
  end

  def test_min_later_than_every_declared_block
    assert_equal "2025-09", PreviewRequest.resolve("preview").name
    assert_raises(Verquest::VersionNotFoundError) { PreviewRequest.resolve("2025-09") }
    assert_raises(Verquest::VersionNotFoundError) { PreviewRequest.to_schema(version: "2026-01") }
  end

  def test_overriding_subclass_serves_every_version
    assert_equal ["reason"], OpenRequest.to_schema(version: "2026-01")["properties"].keys
  end

  def test_references_outside_the_range_raise_when_the_version_is_defined
    assert_raises(Verquest::VersionNotFoundError) do
      Class.new(Verquest::Base) do
        version("2026-01") { reference :overlock, from: OverlockRequest }
      end
    end
  end

  def test_max_before_the_first_declared_version_raises_on_resolve
    request = Class.new(Verquest::Base) do
      supported_versions max: "2025-06"
      version("2025-09") { field :reason, type: :string }
    end

    error = assert_raises(Verquest::DefinitionError) { request.to_schema(version: "2025-09") }

    assert_match(/supported_versions max: 2025-06 is before every declared version \(2025-09\)/, error.message)
  end

  def test_order_follows_the_version_resolver
    with_configuration(version_resolver: NUMERIC) do
      request = Class.new(Verquest::Base) do
        supported_versions max: "v9"
        version("v9") { field :a, type: :string }
        version("v10") { field :b, type: :string }
      end

      assert_equal ["a"], request.to_schema(version: "v9")["properties"].keys
      assert_raises(Verquest::VersionNotFoundError) { request.to_schema(version: "v10") }
    end
  end

  # Known limit: references are checked against the referencing class's declared block, not the request
  def test_references_are_checked_against_the_declared_block
    parent = Class.new(Verquest::Base) do
      version("2025-06") { reference :overlock, from: OverlockRequest }
    end

    assert_equal({"overlock" => {"reason" => "x"}}, parent.process({"overlock" => {"reason" => "x"}}, version: "2026-01"))
  end
end

# frozen_string_literal: true

# Benchmarks Verquest::Base.process on typical requests
#
# Prints the objects allocated per call, then the calls per second.
# Run with `bundle exec rake bench`.

require "verquest"
require "benchmark/ips"

Verquest.configure { |config| config.validation_error_handling = :result }

module ProcessBench
  # A referenced address
  class Address < Verquest::Base
    version "2025-01" do
      field :street, type: :string, required: true
      field :city, type: :string, required: true, map: "town"
      field :zip, type: :string
    end
  end

  # Nested object, reference, collection, array, mapped fields and a format
  class Body < Verquest::Base
    version "2025-06" do
      field :name, type: :string, required: true, map: "full_name"
      field :email, type: :string, format: "email"
      field :age, type: :integer, map: "profile/age"
      enum :status, values: %w[active inactive]
      object :settings do
        field :theme, type: :string
        field :notifications, type: :boolean, map: "/notify"
      end
      reference :address, from: Address
      collection :items, item: Address
      array :tags, type: :string
    end
  end

  # Fields with defaults, at the root and in a nested object
  class Defaults < Verquest::Base
    version "2025-06" do
      field :name, type: :string, required: true
      field :country, type: :string, default: "GB"
      field :enabled, type: :boolean, default: false
      object :settings do
        field :theme, type: :string, default: "light"
      end
    end
  end

  # Typed query params that need coercion
  class Query < Verquest::Base
    location :query

    version "2025-06" do
      field :page, type: :integer, minimum: 1
      field :archived, type: :boolean
      enum :sort_direction, values: %w[ASC DESC]
      array :status, type: :string, explode: false
    end
  end

  BODY = {
    "name" => "Jane", "email" => "jane@example.com", "age" => 33, "status" => "active",
    "settings" => {"theme" => "dark", "notifications" => true},
    "address" => {"street" => "Main 1", "city" => "Prague", "zip" => "11000"},
    "items" => Array.new(10) { |i| {"street" => "S#{i}", "city" => "C#{i}"} },
    "tags" => %w[a b c]
  }.freeze

  CASES = {
    "body" => -> { Body.process(BODY, version: "2025-06") },
    "body (no validate)" => -> { Body.process(BODY, version: "2025-06", validate: false) },
    "defaults" => -> { Defaults.process({"name" => "Jane", "settings" => {}}, version: "2025-06") },
    "query" => -> { Query.process({"page" => "2", "archived" => "true", "sort_direction" => "ASC", "status" => "open,won"}, version: "2025-06") }
  }.freeze

  # @param call [Proc] The benchmarked call
  # @return [Integer] The objects one call allocates
  def self.allocations(call)
    call.call
    before = GC.stat(:total_allocated_objects)
    call.call
    GC.stat(:total_allocated_objects) - before
  end
end

ProcessBench::CASES.each do |name, call|
  result = call.call
  raise "#{name} failed: #{result.errors}" if result.failure?

  puts format("%-20s %5d objects allocated per call", name, ProcessBench.allocations(call))
end

Benchmark.ips do |x|
  x.config(time: 2, warmup: 1)
  ProcessBench::CASES.each { |name, call| x.report(name, &call) }
end

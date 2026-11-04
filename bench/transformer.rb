# frozen_string_literal: true

# Benchmarks Transformer#call on typical requests
#
# Prints the objects allocated per call, then the calls per second.
# Run with `bundle exec rake bench`.

require "verquest"
require "benchmark/ips"

module TransformerBench
  # Nested objects, null objects and a collection, without oneOfs
  class Flat < Verquest::Base
    version "2025-06" do
      field :id, type: :string
      field :note, type: :string, nullable: true

      object :user do
        field :first, type: :string, map: "first_name"
        field :last, type: :string
        object(:site, nullable: true) { field :id, type: :string }
      end

      collection :items do
        field :name, type: :string, map: "title"
        field :qty, type: :integer
        object(:meta, nullable: true) { field :note, type: :string }
      end
    end
  end

  # One nested oneOf with a discriminator
  class Discriminated < Verquest::Base
    version "2025-06" do
      field :id, type: :string

      one_of name: :payment, discriminator: :method do
        object :card do
          const :method, value: "card"
          field :number, type: :string
        end
        object :bank do
          const :method, value: "bank"
          field :iban, type: :string, map: "account"
        end
      end
    end
  end

  # Two nested oneOfs with discriminators
  class Multiple < Verquest::Base
    version "2025-06" do
      field :id, type: :string

      one_of name: :payment, discriminator: :method do
        object :card do
          const :method, value: "card"
          field :number, type: :string
        end
        object :bank do
          const :method, value: "bank"
          field :iban, type: :string
        end
      end

      one_of name: :shipping, discriminator: :type do
        object :post do
          const :type, value: "post"
          field :address, type: :string
        end
        object :pickup do
          const :type, value: "pickup"
          field :store, type: :string
        end
      end
    end
  end

  # A collection whose items hold a oneOf, with a discriminator and without
  class Collection < Verquest::Base
    version "2025-06" do
      collection :pets do
        field :name, type: :string

        one_of name: :kind, discriminator: :type do
          object :dog do
            const :type, value: "dog"
            field :bark, type: :boolean
          end
          object :cat do
            const :type, value: "cat"
            field :meow, type: :boolean
          end
        end
      end

      collection :entries do
        field :entry_id, type: :string

        one_of name: :content do
          object(:text) { field :text, type: :string, required: true }
          object(:number) { field :amount, type: :number, required: true }
        end
      end
    end
  end

  CASES = {
    "flat" => [Flat, {
      "id" => "1", "note" => nil, "user" => {"first" => "a", "last" => "b", "site" => nil},
      "items" => Array.new(20) { |i| {"name" => "n", "qty" => i, "meta" => i.even? ? nil : {"note" => "x"}} }
    }],
    "discriminated" => [Discriminated, {"id" => "1", "payment" => {"method" => "bank", "iban" => "CZ"}}],
    "multiple" => [Multiple, {"id" => "1", "payment" => {"method" => "card", "number" => "4"}, "shipping" => {"type" => "post", "address" => "a"}}],
    "collection" => [Collection, {
      "pets" => Array.new(10) { |i| {"name" => "n", "kind" => i.even? ? {"type" => "dog", "bark" => true} : {"type" => "cat", "meow" => false}} },
      "entries" => Array.new(10) { |i| {"entry_id" => i.to_s, "content" => i.even? ? {"text" => "t"} : {"amount" => 1}} }
    }]
  }.to_h { |name, (request, params)| [name, [request.send(:resolve, "2025-06").transformer, params]] }

  # @param transformer [Verquest::Transformer] The transformer
  # @param params [Hash] The input
  # @return [Integer] The objects one call allocates
  def self.allocations(transformer, params)
    transformer.call(params)
    before = GC.stat(:total_allocated_objects)
    transformer.call(params)
    GC.stat(:total_allocated_objects) - before
  end
end

TransformerBench::CASES.each do |name, (transformer, params)|
  puts format("%-14s %4d objects allocated per call", name, TransformerBench.allocations(transformer, params))
end

Benchmark.ips do |x|
  x.config(time: 2, warmup: 1)
  TransformerBench::CASES.each { |name, (transformer, params)| x.report(name) { transformer.call(params) } }
end

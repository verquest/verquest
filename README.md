# Verquest

[![Gem Version](https://badge.fury.io/rb/verquest.svg)](https://badge.fury.io/rb/verquest)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

Verquest describes your API's requests (bodies, query strings and path parameters) with a small Ruby DSL, one definition per API version. From that definition you get:

- validation of incoming params against [JSON Schema](https://json-schema.org/), with errors that point at the invalid value (`/address/city`);
- mapping from your public API structure to the structure your app uses (`full_name` → `name`);
- JSON Schema components and OpenAPI parameters for your docs, ready for [rswag](https://github.com/rswag/rswag);
- version resolution: ask for `2025-07` and get the closest earlier definition, so unchanged requests need no new version.

It works in any Ruby app and has no Rails dependency. [Rails and rswag](docs/rails.md) shows how to plug it into controllers and request specs.

Sponsored by [Stora](https://stora.co)

> Verquest is not 1.0 yet, so minor releases can change the API; the [changelog](CHANGELOG.md) lists every change. `anyOf` and `allOf` aren't in the DSL yet, see the open [issues](https://github.com/verquest/verquest/issues?q=sort:updated-desc%20is:issue%20is:open%20label:enhancement).

## Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Features](#core-features): [schema definition](#schema-definition-and-validation), [oneOf](#oneof), [conditional schemas](#conditional-schemas), [custom field types](#custom-field-types), [versioning](#versioning), [mapping](#mapping-request-structure), [query parameters](#query-parameters), [filters](#filters), [path parameters](#path-parameters), [OpenAPI components](#component-generation-for-openapi)
- [Rails and rswag](docs/rails.md)
- [Configuration](#configuration)

## Installation

Add this line to your application's Gemfile:

```ruby
gem "verquest", "~> 0.9"
```

And then execute:

```bash
bundle install
```

## Quick Start

### Define a request

A request class inherits from `Verquest::Base` and describes each version in a `version` block. An address, reused below:

```ruby
class AddressCreateRequest < Verquest::Base
  description "Address Create Request"
  schema_options additional_properties: false

  version "2025-06" do # or v1 or anything you need (use a custom version_resolver if needed)
    with_options type: :string, required: true do
      field :street, description: "Street address"
      field :city, description: "City of residence"
      field :postal_code, description: "Postal code"
      field :country, description: "Country of residence"
    end
  end
end
```

A user request that uses the address:

```ruby
class UserCreateRequest < Verquest::Base
  description "User Create Request"
  schema_options additional_properties: false

  version "2025-06" do # or v1 or anything you need (use a custom version_resolver if needed)
    with_options type: :string, required: true do
      field :first_name, description: "The first name of the user", max_length: 50
      field :last_name, description: "The last name of the user", max_length: 50
      field :email, format: "email", description: "The email address of the user"
    end
    
    field :birth_date, type: :string, nullable: true, format: "date", description: "The birth date of the user"

    reference :address, from: AddressCreateRequest, required: true

    collection :permissions, description: "Permissions associated with the user" do
      field :name, type: :string, required: true, description: "Name of the permission"
      
      with_options type: :boolean do
        field :read, description: "Permission to read"
        field :write, description: "Permission to write"
      end
    end
    
    enum :role, values: %w[member manager], default: "member", description: "Role of the user", required: true
    
    object :profile_details do
      field :bio, type: :string, description: "Short biography of the user"
      
      array :hobbies, type: :string, description: "Tags associated with the user"
      
      object :social_links, description: "Some social networks" do
        with_options type: :string, format: "uri" do
          field :github, description: "GitHub profile URL"
          field :mastodon, description: "Mastodon profile URL"
        end
      end
    end
    
    const :company, value: "Awesome Inc."
  end
end
```

### Process params in a Rails controller

`process` validates the params and returns them mapped to your internal structure. It takes `ActionController::Parameters` as they are, so it replaces strong parameters:

```ruby
class UsersController < ApplicationController
  rescue_from Verquest::InvalidParamsError do |error|
    render json: {errors: error.errors}, status: :unprocessable_content
  end

  def create
    user = Users::Create.call(params: UserCreateRequest.process(params, version: params[:api_version]))
    render json: user, status: :created
  end
end
```

Each error points at the invalid value:

```ruby
error.errors
# => [{pointer: "/email", type: "format", message: "value at `/email` does not match format: email", details: nil}]
```

Set `config.current_version` to drop the `version:` argument, or `config.validation_error_handling = :result` to get a `Verquest::Result` instead of an exception (see [Configuration](#configuration)). For query and path parameters in controllers, see [Rails and rswag](docs/rails.md).

### JSON schema for OpenAPI

`to_schema` returns the JSON Schema of a version for your API documentation. References stay `$ref`s:

```ruby
UserCreateRequest.to_schema(version: "2025-06")
```

Output:
```ruby
{
  "type" => "object",
  "description" => "User Create Request",
  "required" => ["first_name", "last_name", "email", "address", "role"],
  "properties" => {
    "first_name" => {"type" => "string", "description" => "The first name of the user", "maxLength" => 50},
    "last_name" => {"type" => "string", "description" => "The last name of the user", "maxLength" => 50},
    "email" => {"type" => "string", "format" => "email", "description" => "The email address of the user"},
    "birth_date" => {"type" => ["string", "null"], "format" => "date", "description" => "The birth date of the user"},
    "address" => {"$ref" => "#/components/schemas/AddressCreateRequest"},
    "permissions" => {
      "type" => "array",
      "items" => {
        "type" => "object", 
        "required" => ["name"], 
        "properties" => {
          "name" => {"type" => "string", "description" => "Name of the permission"}, 
          "read" => {"type" => "boolean", "description" => "Permission to read"}, 
          "write" => {"type" => "boolean", "description" => "Permission to write"}
        },
        "additionalProperties" => false
      },
      "description" => "Permissions associated with the user"
    },
    "role" => {
      "type" => "string",
      "enum" => ["member", "manager"], 
      "default" => "member", 
      "description" => "Role of the user"
    },
    "profile_details" => {
      "type" => "object",
      "properties" => {
        "bio" => {"type" => "string", "description" => "Short biography of the user"},
        "hobbies" => {"type" => "array", "items" => {"type" => "string"}, "description" => "Tags associated with the user"},
        "social_links" => {
          "type" => "object",
          "properties" => {
            "github" => {"type" => "string", "format" => "uri", "description" => "GitHub profile URL"},
            "mastodon" => {"type" => "string", "format" => "uri", "description" => "Mastodon profile URL"}
          },
          "additionalProperties" => false,
          "description" => "Some social networks"
        }
      },
      "additionalProperties" => false
    },
    "company" => {"const" => "Awesome Inc."}
  },
  "additionalProperties" => false
}
```

### JSON schema for validation

`to_validation_schema` returns the schema that `process` validates against, with references inlined:

```ruby
UserCreateRequest.to_validation_schema(version: "2025-06")
```

Output:
```ruby
{
  "type" => "object",
  "description" => "User Create Request",
  "required" => ["first_name", "last_name", "email", "address", "role"],
  "properties" => {
    "first_name" => {"type" => "string", "description" => "The first name of the user", "maxLength" => 50},
    "last_name" => {"type" => "string", "description" => "The last name of the user", "maxLength" => 50},
    "email" => {"type" => "string", "format" => "email", "description" => "The email address of the user"},
    "birth_date" => {"type" => ["string", "null"], "format" => "date", "description" => "The birth date of the user"},
    "address" => { # from the AddressCreateRequest
      "type" => "object",
      "description" => "Address Create Request",
      "required" => ["street", "city", "postal_code", "country"],
      "properties" => {
        "street" => {"type" => "string", "description" => "Street address"},
        "city" => {"type" => "string", "description" => "City of residence"},
        "postal_code" => {"type" => "string", "description" => "Postal code"},
        "country" => {"type" => "string", "description" => "Country of residence"}
      },
      "additionalProperties" => false
    },
    "permissions" => {
      "type" => "array",
      "items" => {
        "type" => "object", "required" => ["name"],
        "properties" => {
          "name" => {"type" => "string", "description" => "Name of the permission"},
          "read" => {"type" => "boolean", "description" => "Permission to read"},
          "write" => {"type" => "boolean", "description" => "Permission to write"}
        },
        "additionalProperties" => false
      },
      "description" => "Permissions associated with the user"
    },
    "role" => {
      "type" => "string",
      "enum" => ["member", "manager"],
      "default" => "member",
      "description" => "Role of the user"
    },
    "profile_details" => {
      "type" => "object",
      "properties" => {
        "bio" => {"type" => "string", "description" => "Short biography of the user"},
        "hobbies" => {"type" => "array", "items" => {"type" => "string"}, "description" => "Tags associated with the user"},
        "social_links" => {
          "type" => "object",
          "properties" => {
            "github" => {"type" => "string", "format" => "uri", "description" => "GitHub profile URL"},
            "mastodon" => {"type" => "string", "format" => "uri", "description" => "Mastodon profile URL"}
          },
          "additionalProperties" => false,
          "description" => "Some social networks"
        }
      },
      "additionalProperties" => false
    },
    "company" => {"const" => "Awesome Inc."}
  },
  "additionalProperties" => false
}
```

`valid_schema?` and `validate_schema` check the validation schema against the meta-schema of `config.json_schema_version`. Under `:openapi30`, they check the `to_schema` document instead, because validation schemas keep JSON Schema forms that OpenAPI 3.0 forbids:

```ruby
UserCreateRequest.valid_schema?(version: "2025-06") # => true/false
UserCreateRequest.validate_schema(version: "2025-06") # => Array of errors or empty array if valid
```

## Core Features

### Schema Definition and Validation

See the example above for how to define a request schema. Verquest provides a DSL to define your API requests with various component types and helper methods based on JSON Schema, which is also used in [OpenAPI specification](https://swagger.io/specification/#schema-object-examples) for components.

The JSON schema can be used for both validation of incoming parameters and for generating OpenAPI documentation components.

#### Component types

- `field`: a scalar value (string, integer, boolean, etc.).
- `enum`: a value from a fixed list. Its `type` is inferred from the values (`string`, `integer`, `number`, `boolean`, `object`, or a type array for mixed values) unless you pass `type:`, and every value must fit it. A value of another class (such as a Symbol), `nil` without `nullable: true`, or values equal in JSON (`1` and `1.0`) raise `ArgumentError`.
- `object`: a JSON object with its own properties.
- `array`: a JSON array of scalar items.
- `collection`: a JSON array of objects, defined inline or with `item:` pointing at another request.
- `reference`: another request reused in place, or one of its properties with `property:`.
- `const`: a [constant](https://json-schema.org/understanding-json-schema/reference/const#constant-values) value.
- `one_of`: exactly one of several request shapes, see [oneOf](#oneof).

#### Helper methods

- `description`: a description for the request, or for one version.
- `schema_options`: extra JSON Schema keywords for the request or one version, such as `additional_properties: false`.
- `with_options`: shared options for every property in the block.

Properties (except `reference`) take JSON Schema keywords in snake case, such as `format`, `min_length` or `max_length`, and Verquest writes them in camel case (`minLength`).

#### Required properties

You can define required properties in your request schema by setting the `required` option to `true`, or provide a list of dependent required properties. This feature is based on the latest [JSON Schema specification](https://json-schema.org/understanding-json-schema/reference/conditionals#dependentRequired), which is also used in OpenAPI 3.1.

```ruby
class DependentRequiredRequest < Verquest::Base
  description "This is a simple request with nullable properties for testing purposes."

  version "2025-06" do
    field :name, type: :string, required: true
    field :credit_card, type: :number, required: %i[billing_address]
    field :billing_address, type: :string
  end
end
```

Will produce this validation schema:

```ruby
{
  "type" => "object",
  "description" => "This is a simple request with nullable properties for testing purposes.",
  "required" => ["name"],
  "dependentRequired" => {"credit_card" => ["billing_address"]},
  "properties" => {
    "name" => {"type" => "string"},
    "credit_card" => {"type" => "number"},
    "billing_address" => {"type" => "string"}
  },
  "additionalProperties" => false
}
```

#### Nullable properties

You can define nullable properties in your request schema by setting the `nullable` option to `true`. This feature is based on the latest JSON Schema specification, which is also used in OpenAPI 3.1.

Nullable enums include Ruby `nil` in their allowed values, which exports as JSON `null`, not the string `"null"`, and add `"null"` to the type, inferred or given. An enum that lists `nil` itself needs `nullable: true`. This also applies to fields with an `enum:` constraint (including custom field types). The supplied values array is not modified.

```ruby
enum :role, values: %w[member admin], nullable: true
# => {"role" => {"type" => ["string", "null"], "enum" => ["member", "admin", nil]}}
# under :openapi30: {"type" => "string", "nullable" => true, "enum" => ["member", "admin", nil]}

const :kind, value: "user", nullable: true
# => {"kind" => {"anyOf" => [{"const" => "user"}, {"type" => "null"}]}}
```

Nullable constants and references use `anyOf` with a null alternative in both exported and validation schemas (except `:openapi30` documents, see below). Nullable `one_of` uses an outer `anyOf` around the original `oneOf` and the null alternative. This allows null even when a referenced schema or multiple variants already accept it, while preserving all restrictions on non-null values. A discriminator, when present, stays alongside the inner `oneOf`.

OpenAPI 3.0 has no `null` type, so with `json_schema_version = :openapi30` documents (`to_schema` and `to_parameters`) write `nullable: true` instead:
- next to the type;
- merged into a nullable constant (with `null` in its `enum`) or a `one_of` without a discriminator;
- next to an `allOf` around a nullable reference (`{"allOf" => [{"$ref" => "..."}], "nullable" => true}`) or a nullable `one_of` with a discriminator, which keeps null outside the discriminated `oneOf`, as versponse does.

OpenAPI 3.0 also has no `dependentRequired` (from `required: [:other]`), so documents write it as the `x-dependentRequired` extension. Validation still enforces it.

Mixed types become an `anyOf` of single types, each nullable when the property is. Strict OpenAPI 3.0.3 tools honour `nullable` only next to `type`, so they may still treat a nullable reference or `one_of` as not nullable. Validation schemas keep the forms above, which validators honour.

Enum values must be JSON values: Strings, Numerics, booleans or Hashes, given as an Array. Hash values need String keys, and everything inside them must be JSON too (Strings, finite numbers, booleans, `nil`, Arrays and Hashes). A BigDecimal or Rational value is a `number`, but Ruby's JSON generator writes it as a string, so prefer Integers and Floats in documented enums.

`required: true` still requires the key to be present; `nullable: true` only permits its value to be null. Defaults stay on the outer nullable schema so missing properties still receive them when default insertion is enabled. Explicit null values are not replaced by defaults.

```ruby
class NullableRequest < Verquest::Base
  description "This is a simple request with nullable properties for testing purposes."

  version "2025-06" do
    with_options nullable: true do
      array :array, type: :string
      collection :collection_with_item, item: ReferencedRequest
      collection :collection_with_object do
        field :field, type: :string, nullable: false
      end

      field :field, type: :string

      object :object do
        field :field, type: :string, nullable: false
      end

      reference :referenced_object, from: ReferencedRequest
      reference :referenced_field, from: ReferencedRequest, property: :simple_field
    end
  end
end
```

Will produce this validation schema:

```ruby
{
  "type" => "object",
  "description" => "This is a simple request with nullable properties for testing purposes.",
  "properties" => {
    "array" => {"type" => %w[array null], "items" => {"type" => "string"}},
    "collection_with_item" => {"type" => %w[array null], "items" => {"type" => "object", "description" => "This is an another example for testing purposes.", "required" => %w[simple_field nested], "properties" => {"simple_field" => {"type" => "string", "description" => "The simple field"}, "nested" => {"type" => "object", "required" => %w[nested_field_1 nested_field_2], "properties" => {"nested_field_1" => {"type" => "string", "description" => "This is a nested field"}, "nested_field_2" => {"type" => "string", "description" => "This is another nested field"}}, "additionalProperties" => false}}, "additionalProperties" => false}},
    "collection_with_object" => {"type" => %w[array null], "items" => {"type" => "object", "properties" => {"field" => {"type" => "string"}}, "additionalProperties" => false}},
    "field" => {"type" => %w[string null]},
    "object" => {
      "type" => %w[object null],
      "properties" => {
        "field" => {"type" => "string"}
      },
      "additionalProperties" => false
    },
    "referenced_object" => {
      "anyOf" => [
        {
          "type" => "object",
          "description" => "This is an another example for testing purposes.",
          "required" => %w[simple_field nested],
          "properties" => {"simple_field" => {"type" => "string", "description" => "The simple field"}, "nested" => {"type" => "object", "required" => %w[nested_field_1 nested_field_2], "properties" => {"nested_field_1" => {"type" => "string", "description" => "This is a nested field"}, "nested_field_2" => {"type" => "string", "description" => "This is another nested field"}}, "additionalProperties" => false}},
          "additionalProperties" => false
        },
        {"type" => "null"}
      ]
    },
    "referenced_field" => {"anyOf" => [{"type" => "string", "description" => "The simple field"}, {"type" => "null"}]}
  },
  "additionalProperties" => false
}
```

#### Conditional schemas

Use `condition` when a request changes shape depending on the payload. It compiles to JSON Schema `if` / `then` / `else` and works in a version, an `object`, and an inline `collection`:

```ruby
version "2025-09" do
  field :effective_from, type: :string, required: true
  field :credit_card, type: :string
  field :billing_address, type: :string

  condition :pricing do
    given { present :percentages }
    then_apply do
      object :percentages, required: true, min_properties: 1 do
        field :unit_types, type: :number, maximum: 9999.99
      end
    end
    else_apply do
      field :percentage, type: :number, required: true, deprecated: true, not: {const: 0}
      object :applies_to, deprecated: true do
        field :unit_types, type: :boolean, map: "/apply_to_unit_types"
      end
    end
  end

  depends_on :credit_card do # condition { given { present :credit_card }; then_apply { ... } }
    present :billing_address
  end
end
```

- `given` (the `if`) holds rules only. `then_apply` and `else_apply` hold rules and property declarations. A condition needs `given` and at least one branch.
- Rules: `present :a, :b`, `absent :a`, `equals :kind, "company"`, `value_in :kind, %w[a b]`, `satisfies :age, minimum: 18`, `any { ... }` and `none { ... }`. Rules in one block must all hold. Inside `given`, `equals`, `value_in` and `satisfies` also require their property.
- Branch properties are listed in the scope's `properties`, so `additionalProperties: false` keeps working and the mapping is the flat union. Each branch gets only rules: its required names, and `false` for properties that only the other branch declares. A missing branch is generated.
- Several conditions on one scope go into `allOf`, one entry each.
- `exclude_conditions :pricing` removes an inherited named condition in a later version. A named condition can be declared only once per scope, so exclude an inherited one before redeclaring it.
- `exclude_properties` only sees regular properties. To drop a branch property, exclude its condition.
- Conditions need `json_schema_version` `:draft7` or later, or `:openapi31`. Other versions ignore `if` / `then` / `else`, so Verquest raises `ArgumentError` when the version is prepared.

The example gives this schema:

```json
{
  "type": "object",
  "required": ["effective_from"],
  "properties": {
    "effective_from": {"type": "string"}, "credit_card": {"type": "string"}, "billing_address": {"type": "string"},
    "percentages": {"...": "..."}, "percentage": {"...": "..."}, "applies_to": {"...": "..."}
  },
  "additionalProperties": false,
  "allOf": [
    {
      "if": {"required": ["percentages"]},
      "then": {"required": ["percentages"], "properties": {"percentage": false, "applies_to": false}},
      "else": {"required": ["percentage"], "properties": {"percentages": false}}
    },
    {"if": {"required": ["credit_card"]}, "then": {"required": ["billing_address"]}}
  ]
}
```

##### Documenting a condition as a oneOf

`document_as: :one_of` keeps `if` / `then` / `else` in the validation schema, but `to_schema` (the documentation) renders a `oneOf` with one variant per branch. `then_apply` and `else_apply` take a `title`, `description` and `deprecated` for their variant:

```ruby
version "2025-09" do
  field :effective_from, type: :string, required: true

  condition :pricing, document_as: :one_of do
    given { present :percentages }
    then_apply title: "Per-type percentages" do
      object :percentages, required: true, min_properties: 1 do
        field :unit_types, type: :number, maximum: 9999.99
      end
    end
    else_apply title: "Shared percentage", deprecated: true do
      field :percentage, type: :number, required: true
    end
  end
end
```

```json
{
  "oneOf": [
    {"type": "object", "title": "Per-type percentages", "required": ["effective_from", "percentages"], "properties": {"effective_from": {"...": "..."}, "percentages": {"...": "..."}}, "additionalProperties": false},
    {"type": "object", "title": "Shared percentage", "deprecated": true, "required": ["effective_from", "percentage"], "properties": {"effective_from": {"...": "..."}, "percentage": {"...": "..."}}, "additionalProperties": false}
  ]
}
```

- Each variant lists the version's properties without the ones only the other branch declares, and adds its branch's rules. The `then` variant also holds the `given` rules, and the `else` variant `not` the `given` rules. A variant leaves them out when its required and forbidden properties already decide them, so `given { absent :percentage }` or `given { any { present :percentages; absent :percentage } }` documents as cleanly as `given { present :percentages }` when the branches require those properties. Values aren't compared, so `equals`, `value_in` and `satisfies` stay in the `then` variant. Both schemas accept the same payloads. When a rule clashes with a property's own schema (for example `given { absent :note }` against a declared `note`, or `satisfies :age, minimum: 18` against `minimum: 0`), the variant keeps both by adding the rule under `allOf`.
- Validation still uses the `if` / `then` / `else` schema, so validation errors point at those rules, not at a `oneOf` variant.
- When `additionalProperties` isn't `false`, the other branch's properties are forbidden with `false` in each variant.
- Only for a condition in a version, and it must be the only condition in that version. The version's `description` stays at the root of the schema.
- The schema has no root `properties`, so `to_ref(property:)` can't point into it.

#### oneOf

`one_of` accepts exactly one of several shapes. Each variant is a `reference` to another request, and `discriminator:` names the property that tells them apart:

```ruby
class CardPaymentComponent < Verquest::Base
  version "2025-06" do
    const :method, value: "card", required: true
    field :card_number, type: :string, required: true
    field :expiry, type: :string, required: true
  end
end

class OrderRequest < Verquest::Base
  version "2025-06" do
    field :order_id, type: :string, required: true

    one_of name: :payment, discriminator: :method, required: true do
      reference :card, from: CardPaymentComponent
      reference :bank, from: BankPaymentComponent
    end
  end
end

OrderRequest.process({"order_id" => "o1", "payment" => {"method" => "card", "card_number" => "4242", "expiry" => "12/30"}})
# => {"order_id" => "o1", "payment" => {"method" => "card", "card_number" => "4242", "expiry" => "12/30"}}
```

`to_schema` documents it as an OpenAPI `oneOf` with a `discriminator` mapping to the variants' components:

```ruby
{"oneOf" => [{"$ref" => "#/components/schemas/CardPaymentComponent"}, {"$ref" => "#/components/schemas/BankPaymentComponent"}],
 "discriminator" => {"propertyName" => "method", "mapping" => {"card" => "#/components/schemas/CardPaymentComponent", "bank" => "#/components/schemas/BankPaymentComponent"}}}
```

- Without `name:`, the whole request is one of the variants (`one_of discriminator: :type do ... end` as the only property of a version).
- Without `discriminator:`, the value must match exactly one variant's schema. Validation rejects it otherwise; with validation off, mapping raises `Verquest::MappingError`.
- `one_of` works inside objects, collections and other variants, and with `nullable: true` and `map:`.

#### oneOf discriminators in validation

A `one_of` with a `discriminator:` keeps the discriminator in the validation schema. Its variants move into local `definitions` that `oneOf` references with `$ref`. An id, written as both `$id` and `id` so every JSON Schema version reads it, makes those references resolve wherever the schema is embedded:

```ruby
one_of name: :pet, discriminator: :type do
  reference :dog, from: DogComponent
  reference :cat, from: CatComponent
end
```

```json
{
  "$id": "https://verquest.local/one_of/3f1c9a0b2d4e5f67",
  "id": "https://verquest.local/one_of/3f1c9a0b2d4e5f67",
  "definitions": {"dog": {"type": "object", "...": "..."}, "cat": {"type": "object", "...": "..."}},
  "oneOf": [{"$ref": "#/definitions/dog"}, {"$ref": "#/definitions/cat"}],
  "discriminator": {"propertyName": "type", "mapping": {"dog": "#/definitions/dog", "cat": "#/definitions/cat"}}
}
```

With `json_schema_version = :openapi31` or `:openapi30`, the validator checks only the variant the discriminator selects, so validation errors come from that variant only. A value that isn't an object, or that has no known discriminator value, gets a single `discriminator` error. Other versions ignore `discriminator` and check every variant.

#### Custom Field Types

You can define custom field types that can be used in `field` and `array` in the configuration.

```ruby
Verquest.configure do |config|
  config.custom_field_types = {
    email: {
      type: "string",
      schema_options: {format: "email"}
    },
    uuid: {
      type: "string",
      schema_options: {format: "uuid"}
    }
  }
end
```

Then you can use it in your request:
```ruby
class EmailRequest < Verquest::Base
  description "User Create Request"
  schema_options additional_properties: false

  version "2025-06" do
    field :email, type: :email
    array :uuids, type: :uuid
  end
end
```

`EmailRequest.to_schema(version: "2025-06")` will then generate the following JSON Schema:
```ruby
{
  "type" => "object",
  "description" => "User Create Request",
  "properties" => {
    "email" => {
      "type" => "string", 
      "format" => "email"
    },
    "uuids" => {
      "type" => "array", 
      "items" => {
        "type" => "string",
        "format" => "uuid"
      }
    }
  },
  "additionalProperties" => false
}
```

### Versioning

Verquest allows you to define multiple versions of your API requests, making it easy to evolve your API over time:

```ruby
class UserCreateRequest < Verquest::Base
  version "2025-04" do    
    field :name, type: :string, required: true
    field :email, type: :string, format: "email", required: true

    field :street, type: :string
    field :city, type: :string
  end
  
  # Implicit inheritance from the previous version
  version "2025-06", exclude_properties: %i[street city] do
    field :phone, type: :string
    
    # Replace street and city with a structured address object with zip
    object :address do
      field :street, type: :string
      field :city, type: :string
      field :zip, type: :string
    end
  end
  
  # Disabled inheritance, `inherit` can also be set to a specific version
  version "2025-08", inherit: false do
    field :name, type: :string, required: true
    field :email, type: :string, format: "email", required: true
    field :phone, type: :string
    
    # Replace address with a more structured version
    object :address do
      field :street_line1, type: :string, required: true
      field :street_line2, type: :string
      field :city, type: :string, required: true
      field :state, type: :string
      field :postal_code, type: :string, required: true
      field :country, type: :string, required: true
    end
  end
end
```

`Verquest::VersionResolver` picks the version block for the requested version. When no block matches exactly, it picks the closest earlier one:

```ruby
UserCreateRequest.process(params, version: "2025-05") # => use the defined version "2025-04"
UserCreateRequest.process(params, version: "2025-06") # => use the defined version "2025-06"
UserCreateRequest.process(params, version: "2025-07") # => use the closest earlier version "2025-06"
UserCreateRequest.process(params, version: "2025-08") # => use the defined version "2025-08"
UserCreateRequest.process(params, version: "2025-10") # => use the closest earlier version "2025-08"
```

References resolve the same way. When `UserCreateRequest` references `AddressCreateRequest`, the requested version also picks the `AddressCreateRequest` block, so the two classes can declare different versions.

A new API version that doesn't change a request needs no new `version` block in it.

#### Supported versions

`supported_versions` limits the versions a request serves. Both bounds are inclusive and optional:

```ruby
class OverlockRequest < Verquest::Base
  supported_versions min: "2025-09", max: "2026-03"

  version "2025-09" do
    field :reason, type: :string, required: true
  end
end

OverlockRequest.process(params, version: "2025-12") # => uses the defined version "2025-09"
OverlockRequest.process(params, version: "2026-06") # => raises Verquest::VersionNotFoundError
```

- `min` defaults to the first declared version. Set it when the request should appear later than its first `version` block. The range applies to the requested version, not to the blocks: with `supported_versions min: "preview"` and a single `version "2025-09"` block, `"preview"` is served by the 2025-09 block and `"2025-09"` raises.
- `max` defaults to no upper bound.
- A version outside the range raises `Verquest::VersionNotFoundError`, the same error as a version older than every declared one. `process`, `to_schema`, `to_validation_schema`, `mapping` and references from other requests all respect it. A request that references `OverlockRequest` from a version outside its range raises when that version is defined.
- Known limit: references are checked against the referencing class's declared version, not the requested one. If `ParentRequest` declares only `version "2025-06"` with `reference :overlock, from: OverlockRequest`, then `ParentRequest.process(params, version: "2026-06")` resolves to the 2025-06 block and still serves the reference. To stop serving a retired reference, the parent must declare a later block without it, or its own `supported_versions`.
- Versions are compared with `config.version_resolver`. With the default resolver they compare as strings, so `"preview"` sorts after dated versions.
- `min` after `max` raises `Verquest::DefinitionError` when declared. A `max` before the first declared version would leave nothing to serve, so it raises `Verquest::DefinitionError` the first time the request resolves a version.
- Declare it before the first `version` block. Subclasses inherit the range and can declare their own. `supported_versions` with no arguments removes an inherited range.
- `inherit: "<version>"` copies any declared version, even one outside the range.

### Mapping request structure

`map:` turns the public request structure into the structure your app uses. In this example, the app stores the address in the users table, so the address fields move to the root:

```ruby
class UserCreateRequest < Verquest::Base
  version "2025-06" do
    field :full_name, type: :string, map: "name"
    field :email, type: :string, format: "email", required: true
    field :phone, type: :string
    
    object :address do
      field :street, type: :string, map: "/address_street"
      field :city, type: :string, map: "/address_city"
      field :postal_code, type: :string, map: "/address_zip"
    end
  end
end
```

`UserCreateRequest.process` turns these params:

```ruby
{
  "full_name" => "John Doe",
  "email" => "john@doe.com",
  "phone" => "1234567890",
  "address" => {
    "street" => "123 Main St",
    "city" => "Springfield",
    "postal_code" => "12345"
  }
}
```

into:

```ruby
{
  "name" => "John Doe",
  "email" => "john@doe.com",
  "phone" => "1234567890",
  "address_street" => "123 Main St",
  "address_city" => "Springfield",
  "address_zip" => "12345"
}
```

`map:` takes one of these forms:

- `"name"`: a key at the same level;
- `"/name"`: a key at the root;
- `"nested/structure"`: a key inside nested objects.

Without `map:`, the property name is the key.

`external_mapping` returns the mapping back, from internal keys to external paths:

```ruby
UserCreateRequest.external_mapping(version: "2025-06")
```

Will produce the following mapping:

```ruby
{
  "name" => "full_name",
  "email" => "email",
  "phone" => "phone",
  "address_street" => "address/street",
  "address_city" => "address/city",
  "address_zip" => "address/postal_code"
}
```

The mapping tests in [`test/verquest/base_test.rb`](test/verquest/base_test.rb) have more examples.

### Query parameters

A request class with `location :query` describes query parameters. `process` converts the query strings to the types the schema expects before it validates and maps them, and `to_parameters` documents them as OpenAPI parameters.

```ruby
class DealsIndexQuery < Verquest::Base
  location :query # inherited, so it can be set once on a base class

  version "2025-06" do
    field :page, type: :integer, minimum: 1, default: 1
    field :archived, type: :boolean
    enum :sort_direction, values: %w[ASC DESC], default: "DESC"
    filter :status, as: :array, type: :string, explode: false, item_schema_options: {enum: %w[open won lost]} do |deals, value|
      deals.where(status: value)
    end

    object :created do # sent as created[after]=...
      field :after, type: :string, format: "date-time", map: "/created_after"
    end
  end

  version "2025-08" do # inherits the 2025-06 properties and filters
    filter :site_id, type: :string do |deals, value|
      deals.where(site_id: value)
    end
  end
end

DealsIndexQuery.process(request.query_parameters, version: "2025-06")
# ?page=2&archived=true&status=open,won&created[after]=2025-01-01T00:00:00Z
# => {"page" => 2, "archived" => true, "sort_direction" => "DESC", "status" => ["open", "won"], "created_after" => "2025-01-01T00:00:00Z"}
```

`filter :status, as: :array` declares the same property as `array :status`, plus a block that [Filters](#filters) describes.

Conversion follows the validation schema:
- `integer` and `number` from digits (`"2"`, `"-1.5"`), `boolean` from `"true"` and `"false"`, `null` from an empty string when the schema allows it (a string outside an enum's values tries the next type, so `""` is `nil` in a nullable string enum);
- arrays split on commas with `explode: false` (`status=open,won`), or come from repeated keys with `explode: true` (`status[]=open&status[]=won`; Rails keeps only the last value of a plain repeated key). `config.query_array_explode` sets the default (`true`);
- objects (`deepObject`, one level deep) convert each property.

A value that can't be converted is left as it is, so the validation reports it. Shapes a query string can't express (`one_of` properties, arrays of objects, objects inside objects) raise `Verquest::DefinitionError` when the version is defined.

`to_parameters` returns one parameter object per property, with symbol keys and the schema inlined, ready for rswag:

```ruby
DealsIndexQuery.to_parameters(version: "2025-06").each { |p| parameter(p) }
# {name: "status", in: :query, required: false, style: :form, explode: false,
#  schema: {type: "array", items: {type: "string", enum: ["open", "won", "lost"]}}}
```

Named OpenAPI examples go on the parameter with `parameter_examples:`. They are left out of the JSON schemas, because JSON Schema `examples` is an array:

```ruby
array :status, type: :string, explode: false, item_schema_options: {enum: %w[open won lost]},
  parameter_examples: {single: {value: %w[open]}, multiple: {value: %w[open won]}}
# => {name: "status", ..., examples: {single: {value: ["open"]}, multiple: {value: ["open", "won"]}}, schema: {...}}
```

A property reference to another query class reuses its definition, e.g. a shared `expand` parameter: `reference :expand, from: ExpandQuery, property: :expand`.

#### Lenient requests

Tightening validation can break clients of a released version. `config.lenient_through` makes query and path requests for that version, or an earlier one, correct values instead of rejecting them. Later versions and body requests stay strict, and `process(..., lenient: true/false)` overrides the setting per call.

```ruby
Verquest.configure do |config|
  config.lenient_through = "2025-06"
end
```

| Rule | Value sent | Correction |
|------|------------|------------|
| `blank` | `page=` | Removed, where strict validation would reject it (not for required properties, arrays, properties that accept null, or strings without constraints, also as an anyOf or oneOf variant) |
| `enum_case` | `sort_direction=desc` | `"DESC"`, when exactly one enum value matches case-insensitively |
| `maximum` | `limit=200` | Capped at the `maximum`, `100` |
| `datetime_offset` | `2025-01-12 15:30:00`, `...+0100` | `T` between the date and the time, and `Z` added or a colon added to the offset (`+01:00`) |
| `invalid` | `page=0` | Removed when it still fails validation, except a filter or a required property, which is still rejected |

A value gets at most one correction: a value that is still invalid after a correction is removed, except a filter or a property required by `required`, `dependentRequired` or a condition, which fails validation with its own error, as in strict requests. This is conservative: a property any `dependentRequired` or condition can require is kept even when the trigger is absent or the condition doesn't apply. `process` yields a `Verquest::Correction` for each, also before it raises for a validation failure: `path` is the JSON pointer of the corrected value (`/status/0`, `/created/gte`, or the removed root property), `name` its root property, `rule`, `from` as sent and `to`:

```ruby
params = ListQuery.process(request.query_parameters) do |correction|
  logger.info(correction.to_h.except(:from)) # `from` is what the client sent
end
```

### Filters

`filter` declares a property and the block that filters by its value. The property is a `field` by default, an `array` with `as: :array`, or an `enum` with `as: :enum`, in a body or a query request. `apply_filters` passes the target through the version's filters in declaration order, and skips a filter when its value is nil or empty. `DealsIndexQuery` from [Query parameters](#query-parameters) filters by `status` from `2025-06`, and also by `site_id` from `2025-08`:

```ruby
params = DealsIndexQuery.process(request.query_parameters, version: "2025-08")
DealsIndexQuery.apply_filters(Deal.all, params, version: "2025-08")
DealsIndexQuery.filter_names(version: "2025-08") # => ["status", "site_id"]
```

- Filters follow the rules of properties. A later version inherits them, `exclude_properties` removes one, and redeclaring a filter replaces its block. Redeclaring it as a plain property, such as `field :status`, stops it filtering.
- `reference` copies the property without its filter.
- The block runs only from `apply_filters`, with `self` set to the request class.
- `apply_filters` reads the params by their String names, as `process` returns them. With `validation_error_handling = :result`, pass the result's `value`.
- A filter must be at the root of a version, and it can't use `map:`. Otherwise defining the version raises `Verquest::DefinitionError`.

[`test/support/examples/deals_index_query.rb`](test/support/examples/deals_index_query.rb) runs the same query against an Array of Hashes.

#### Reject keys from other versions

`process` drops root keys that the version doesn't declare. A client that sends `site_id` to `2025-06` gets an unfiltered list and no error. With `reject_other_version_keys: true`, `process` reports a root key that only another version declares as a validation error:

```ruby
DealsIndexQuery.process({"site_id" => "site_1"}, version: "2025-06", reject_other_version_keys: true)
# raises Verquest::InvalidParamsError with
# [{pointer: "/site_id", type: "other_version", message: "`site_id` isn't available in version 2025-06", details: nil}]
```

`remove_extra_root_keys` still drops keys that no version declares, such as `utm_source`. The check works for body requests too, and runs only when `process` validates the params. `config.reject_other_version_keys` sets the default (`false`).

### Path parameters

`location :path` works like `location :query`, but documents `in: :path` parameters. Path parameters must be required scalars; arrays, objects, one_of and optional properties raise `Verquest::DefinitionError`.

```ruby
class DealPath < Verquest::Base
  location :path

  version "2025-06" do
    field :id, type: :string, required: true, pattern: "^deal_", description: "The ID of the deal"
  end
end

DealPath.process({"id" => params[:id]}) # raises Verquest::InvalidParamsError for "con_123"
DealPath.to_parameters(version: "2025-06")
# => [{name: "id", in: :path, required: true, description: "The ID of the deal", schema: {type: "string", pattern: "^deal_"}}]
```

The parameter name comes from the property. When a route uses another name (`/deals/{deal_id}/win`), rename the key before `process` and the `name` of the parameter object, as the [Rails and rswag](docs/rails.md) example does.

### Rails and rswag

See [Rails and rswag](docs/rails.md) for a controller concern that processes body, query and path classes, and an rswag shared context that documents them.

### Component Generation for OpenAPI

Generate JSON Schema, component name and reference for OpenAPI documentation:

```ruby
UserCreateRequest.component_name # => "UserCreateRequest"
UserCreateRequest.to_ref # => "#/components/schemas/UserCreateRequest"
component_schema = UserCreateRequest.to_schema(version: "2025-06")
```

## Configuration

Configure Verquest globally:

```ruby
Verquest.configure do |config|
  # Enable validation by default
  config.validate_params = true # default
  
  # Set the default version to use
  config.current_version = -> { Current.api_version }
  
  # Set the JSON Schema version
  config.json_schema_version = :draft2020_12 # default
  
  # Set the error handling strategy for processing params
  config.validation_error_handling = :raise # default, can be set also to :result
  
  # Remove extra root keys from provided params
  config.remove_extra_root_keys = true # default

  # Report root keys that only another version declares, see Filters
  config.reject_other_version_keys = false # default
  
  # Set custom version resolver
  config.version_resolver = CustomVersionResolver # default is `Verquest::VersionResolver`
  
  # Set default value for additional properties
  config.default_additional_properties = false # default

  # Default explode value of query arrays (true: status[]=a&status[]=b, false: status=a,b)
  config.query_array_explode = true # default

  # Last version whose query and path requests are corrected instead of rejected, see Lenient requests
  config.lenient_through = nil # default

  # Reusable field types, see Custom Field Types
  config.custom_field_types = {} # default
end
```

## Documentation

The API reference is on [RubyDoc](https://www.rubydoc.info/gems/verquest). Guides:

- [Rails and rswag](docs/rails.md): controllers and request specs for body, query and path parameters.

## Development

After checking out the repo, run `bin/setup` to install dependencies. `bundle exec rake` runs the tests, RuboCop and the YARD documentation check; `COVERAGE=1 bundle exec rake` adds a coverage report. `bin/console` opens an interactive prompt with the gem loaded.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `gem_version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/verquest/verquest. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/verquest/verquest/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Verquest project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/verquest/verquest/blob/main/CODE_OF_CONDUCT.md).

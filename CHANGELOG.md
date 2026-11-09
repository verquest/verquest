## [Unreleased]

## [0.10.0] - 2026-11-09

### Added
- `config.lenient_through = "2025-06"` makes query and path requests for that version or an earlier one lenient; `process(..., lenient: true/false)` overrides it per call. A lenient request corrects values instead of rejecting them: blank root values are removed where strict validation would reject them (not for required properties, arrays, properties that accept null, or strings without constraints, also as an anyOf or oneOf variant), enum values match case-insensitively when one value matches, numbers above `maximum` are capped, date-times (with at most 9 fraction digits) without an offset get `Z` and `+HHMM` offsets a colon, with `T` between the date and the time, and root properties that still fail validation are removed, except filters and properties required by `required`, `dependentRequired` or a condition. A value gets at most one correction. `process` yields a `Verquest::Correction` (`path` as the JSON pointer of the corrected value, `rule`, `from` as sent, `to`, and `name` of the root property) for each, also before raising for a validation failure.
- `property_names(version:)` lists the root property names a version declares, inherited ones included, in declaration order.

### Changed
- The private `Query::Coercer` type hooks `coerce_integer`, `coerce_number` and `coerce_string` take `(value, value_schema, path)`. A subclass overriding them must accept the new arguments.

## [0.9.0] - 2026-11-09

### Added
- `filter` declares a property with `field`, `array` or `enum` (`as:`) and the block that filters by its value; `apply_filters(target, params, version:)` runs a version's filters in declaration order, skipping nil and empty values, and `filter_names(version:)` lists them. Filters are inherited, excluded and replaced with their properties. A filter with `map:`, another `as:`, no block, or outside a version's root raises `Verquest::DefinitionError`.
- `process(..., reject_other_version_keys: true)` (or `config.reject_other_version_keys`) reports root keys that only another version declares as validation errors of type `other_version`, when params are validated.

### Changed
- Validation skips json_schemer's default insertion when the schema declares no `default`, which makes `process` about 15% faster for such schemas.

### Fixed
- `process` no longer inserts defaults into the caller's nested hashes, and no longer raises `FrozenError` for frozen nested params when it inserts defaults.

## [0.8.0] - 2026-11-06

### Changed
- **Breaking:** `enum` writes a `type` next to its values and checks the values when the request is defined. Without `type:`, the type is inferred: Strings are `string`, Integers `integer`, other Numerics `number`, `true`/`false` `boolean`, Hashes `object`; Integers next to other Numerics are `number`, and other mixes a type array. These now raise `ArgumentError`:
  - a value of another class, such as a Symbol (Symbols never matched JSON values) or an Array;
  - `nil` in the values without `nullable: true`;
  - a `type:` other than the five above, or one a value doesn't fit;
  - values equal in JSON, such as `1` and `1.0` (also inside Hashes);
  - NaN or Infinity;
  - `values:` that isn't an Array;
  - a Hash value with a key that isn't a String, or with something inside that isn't JSON (such as a Symbol).

  `nullable: true` adds `"null"` to the type, inferred or given. `with_options(type:)` no longer applies to enums.
- With `json_schema_version = :openapi30`, documents (`to_schema` and `to_parameters`) use OpenAPI 3.0 forms: `nullable: true` instead of a `"null"` type, an `anyOf` of single types (each nullable) instead of a type array, a nullable constant as an `enum` with `null`, an `allOf` around a nullable `$ref` or discriminated `one_of`, and `x-dependentRequired` instead of `dependentRequired`. Validation schemas keep the JSON Schema forms validators honour.
- Under `:openapi30`, `valid_schema?` and `validate_schema` check the document (`to_schema`) instead of the validation schema, whose JSON Schema forms made the check fail for any nullable request.
- Schemas leave out `required` when nothing is required, instead of an empty array, which draft 4 and OpenAPI 3.0 forbid. Validation is unchanged. `present` and `absent` without a property name raise `ArgumentError`.

### Fixed
- Query params convert `""` to `nil` in nullable string and mixed enums, and in nullable fields with `enum:`.

## [0.7.1] - 2026-11-06

### Added
- `reference from:` and `collection item:` accept classes that only implement `to_ref` and `to_validation_schema` (such as versponse responses). Their schema is referenced and their value passes through unchanged. They can't be `one_of` variants.
- `supported_versions min:, max:` limits the versions a request serves (both inclusive, both optional; `min` defaults to the first declared version). Resolving a version outside the range raises `Verquest::VersionNotFoundError`, so `process`, schemas, mappings and references respect it. Only the requested version is checked, so `min: "preview"` can be served by an earlier block. `min` after `max`, or a `max` before the first declared version, raises `Verquest::DefinitionError`. Versions are compared with `config.version_resolver`, and subclasses inherit the range. Known limit: references are checked against the referencing class's declared version, not the requested one, so a parent must declare a later block, or its own range, to stop serving a retired reference.

### Fixed
- `collection item:` validation referenced an undefined `type` variable.
- `version ..., inherit: "<version>"` copied the previous version instead of the named one.
- `config.custom_field_types=` no longer modifies the Hash it is given.

### Changed
- `document_as: :one_of` leaves the `given` rules out of a variant when the variant's required and forbidden properties already decide them, including `absent`, `any` and `none`. Before, only `present` (in the `then` variant) and a required property the `else` variant forbids were left out, so `given { absent :percentage }` added `"percentage": false` and a `not` to the variants. The documented schema accepts the same payloads as before.

## [0.7.0] - 2026-11-05

### Added
- Query parameters: `location :query` on a request class converts query strings to the types its schema expects (numbers, booleans, null, comma-separated or repeated arrays, one level of `deepObject`) before `process` validates and maps them. `to_parameters(version:)` returns OpenAPI parameter objects with symbol keys for rswag. Arrays take `explode:`, defaulting to the new `config.query_array_explode` (`true`). `parameter_examples:` on `field`, `enum`, `const`, `array`, `object` and `reference` adds named OpenAPI examples to the parameter without putting them in the JSON schemas. Shapes query strings can't express raise the new `Verquest::DefinitionError` when the version is defined.
- Path parameters: `location :path` converts and validates path params like query params, and `to_parameters` documents them as `in: :path`. Properties must be required scalars, otherwise the version raises `Verquest::DefinitionError`.
- Conditional schemas: `condition` with `given`, `then_apply` and `else_apply` compiles to JSON Schema `if` / `then` / `else` in a version, an `object` or an inline `collection`. Rules: `present`, `absent`, `equals`, `value_in`, `satisfies`, `any` and `none`. Branch properties are listed in the scope's `properties` (so `additionalProperties: false` keeps working and the mapping stays flat), and each branch forbids the properties only the other branch declares, which gives one validation error per problem. Also adds the `depends_on` shorthand and `exclude_conditions` for later versions. Conditions need `json_schema_version` `:draft7` or later, or `:openapi31`; other versions raise `ArgumentError`.
- [Rails and rswag guide](docs/rails.md): a controller concern for body, query and path classes, and an rswag shared context.
- `condition ..., document_as: :one_of` documents a condition in a version as a `oneOf` of its branches in `to_schema`, while the validation schema keeps `if` / `then` / `else`. `then_apply` and `else_apply` take `title`, `description` and `deprecated` for their variant.

### Changed
- A `one_of` with a `discriminator:` keeps the discriminator in the validation schema. Its variants move into local `definitions` referenced by `$ref`, under a content-hash id written as both `$id` and `id` (`https://verquest.local/one_of/...`). With `json_schema_version = :openapi31` or `:openapi30`, validation errors come only from the variant the discriminator selects, and a missing, unknown or non-object value gets a single `discriminator` error. Under `:openapi30`, valid payloads that were rejected with `oneOf` errors (OpenAPI 3.0 has no `const`, so they matched every variant) now pass. Other versions validate as before, but `to_validation_schema` output changes. If you register these schemas with another validator, note the new ids.
- The transformer builds one plan at initialization and is frozen. `Verquest::NOT_FOUND` moved to `Verquest::Transformer::Path::NOT_FOUND`. In the mapping, `_variant_path` and `_nullable_path` hold the full source path inside collections too (`entries[]/content` instead of `content`).
- A `null` oneOf maps to `null` whether it has a discriminator or not, and inside multiple oneOfs.
- A oneOf inside a `collection` is listed in the mapping's `_oneOfs` array, like several oneOfs, instead of putting its metadata at the top level.
- A oneOf variant property moved out of a collection item with `map: "/..."` raises `Verquest::MappingError` when the class is defined. Each item selects its own variant, so it can't be collected outside the items.
- The transformer allocates two to four times fewer objects per call and runs 15–40% faster. `rake bench` measures it.
- A version compiles its validation schema once per configuration instead of on every `process`, which makes `process` with validation up to 4 times faster.
- Under `json_schema_version` `:draft4` and `:openapi30`, which have no `const`, a `const` property is written as a one-value `enum` in `to_schema` and `to_validation_schema`, so it is enforced.
- An unnamed `one_of` next to other properties raises `ArgumentError` when it is declared. It was dropped from the schema.
- Versions build their transformer from their properties instead of from their `mapping` hash, so the transformer no longer depends on the mapping's metadata keys.

### Deprecated
- `Verquest::Transformer.new(mapping:, discriminator:)`. Use `MyRequest.process`, or `MyRequest.resolve(version).transformer`; versions build their transformer from their properties, and the mapping constructor will be removed in 1.0.0. It warns when deprecation warnings are on (`Warning[:deprecated] = true` or `ruby -W:deprecated`), which Ruby leaves off by default.

### Fixed
- A `one_of` inside an `object` mapped a valid payload to an empty hash, and two of them clashed. It also works inside an object in a collection.
- Empty collection items are kept (they were dropped, or became `nil` before a later item), and a `null` nested object inside an item stays `null`.
- A `null` nullable oneOf with a nested `map:` (e.g. `"billing/payment"`) is written as a nested key, not as the literal key `"billing/payment"`.
- A collection item without its optional oneOf, or with a `null` nullable one, no longer raises "No matching schema found". A nullable oneOf without a discriminator in a collection can be defined (the duplicate-mapping check counted its metadata).
- Properties whose names start with `_` are mapped next to oneOfs and inverted in `external_mapping`.
- A collection with `map:` and a oneOf no longer nests every item under the collection name again, also when a variant's first property is moved out with `map: "/..."`.
- Without validation, a present oneOf without its discriminator raises "Missing discriminator" instead of mapping to an empty hash, and an unknown value raises in collection items too. A value naming a metadata key no longer crashes with `NoMethodError`.
- Variant inference (a oneOf without a discriminator) reads the variant schemas in the configured `json_schema_version`. Under draft 4, a boolean `exclusive_maximum` crashed it. Under draft 4 and OpenAPI 3.0, which have no `const`, it reads `const` as a one-value `enum`, so variants that differ only by a const are still told apart.
- oneOfs in a collection inside a collection, and in several collections of one version, are mapped. Before, the discriminator read an array of values, and the second collection's oneOf overwrote the first one's.
- A property moved out of collection items with `map: "/..."` writes `null` for items without the value, instead of an internal object. In a collection holding a oneOf, it is collected outside the items again.
- `external_mapping` inverts the oneOfs nested in objects and collections, which were left as a hash key.
- A `reference`, or a `collection` with `item:`, to a request holding a oneOf no longer drops its data.
- A oneOf inside a oneOf variant, inline or referenced, maps its data, and so does a collection of oneOfs inside a variant. The data was dropped. In `mapping` and `external_mapping`, such a nested oneOf is listed in the variant's `_oneOfs` array, where it used to show up as prefixed metadata keys and stringified hashes.
- In `mapping` and `external_mapping`, an absolute `map:` in a request used as a oneOf reference variant points to the root, as the transformer always mapped it. It was nested under the variant.
- A `reference` with `property:` to an object, a collection or a oneOf maps its data. Only scalar properties worked.
- A collection whose only property is a named `one_of` keeps the name in its item schema, so valid items pass validation.

## [0.6.4] - 2026-09-23

### Fixed
- Handling `nullable: true` ([#18](https://github.com/verquest/verquest/pull/18), [@CiTroNaK](https://github.com/CiTroNaK))

## [0.6.3] - 2026-03-17

### Fixed
- Transformer fixes: fix null propagation, unknown discriminator, and null variant path.

## [0.6.2] - 2025-12-09

### Fixed
- The `item_schema_options` is now properly passed to the `Array` property.

## [0.6.1] - 2025-10-13

### Fixed
- Mapping for collections (array of objects). ([#15](https://github.com/verquest/verquest/pull/15), [@CiTroNaK](https://github.com/CiTroNaK))

## [0.6.0] - 2025-07-18

### Breaking Changes
- **BREAKING:** Switching to slash notation for mapping to improve consistency with how properties are referenced in JSON Schema. Before: `example.nested.property`, now: `example/nested/property`. ([#12](https://github.com/verquest/verquest/pull/12), [@CiTroNaK](https://github.com/CiTroNaK))

### New Features
- Add support for `enum` properties. ([#13](https://github.com/verquest/verquest/pull/13), [@CiTroNaK](https://github.com/CiTroNaK))
- Add support for inverted mapping, that can be used to map internal structure to external representation (e.g., for errors). ([#10](https://github.com/verquest/verquest/pull/10), [@CiTroNaK](https://github.com/CiTroNaK))
- Add support for constants in the schema, allowing to define fixed values for properties. ([#11](https://github.com/verquest/verquest/pull/11), [@CiTroNaK](https://github.com/CiTroNaK))

## [0.5.0] - 2025-07-01

### Fixed
- Handling `with_options` defaults like required and nullable.

### New Features
- Add `default_additional_properties` option to configuration.
- Add support for nullable properties (`nullable: true`) based on the latest JSON Schema specification, which is also used in OpenAPI 3.1.
- Add support for `dependentRequired` (see https://json-schema.org/understanding-json-schema/reference/conditionals#dependentRequired).

## [0.4.0] - 2025-06-28

### Breaking Changes
- **BREAKING:** Renaming validation method from `validate_schema` to `valid_schema?` to better reflect its purpose.
- **BREAKING:** The `validate_schema` now returns an array of errors instead of a boolean value, allowing for more detailed error reporting.

### New Features
- Add support for custom field types.

### Fixed
- Loading the gem in another project with `zeitwerk` now works correctly.
- Fix schema validation after `json_schemer` refactoring.

## [0.3.0] - 2025-06-25

### Breaking Changes
- **BREAKING:** Replace `json-schema` gem with `json_schemer` for support of newer JSON Schema specifications (set the lasest by default).
- **BREAKING:** Schema and validation schema now uses string keys instead of symbols.

### Added
- Allow insert default values for properties when validation is used.

## [0.2.1] - 2025-06-22

- Bump the gem to use Ruby 3.2 as the minimum version.

## [0.2.0] - 2025-06-22

- Initial support for versions, fields, collections, and references.

## [0.1.0] - 2025-06-14

- Initial release

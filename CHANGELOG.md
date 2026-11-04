## [Unreleased]

### Added
- Conditional schemas: `condition` with `given`, `then_apply` and `else_apply` compiles to JSON Schema `if` / `then` / `else` in a version, an `object` or an inline `collection`. Rules: `present`, `absent`, `equals`, `value_in`, `satisfies`, `any` and `none`. Branch properties are listed in the scope's `properties` (so `additionalProperties: false` keeps working and the mapping stays flat), and each branch forbids the properties only the other branch declares, which gives one validation error per problem. Also adds the `depends_on` shorthand and `exclude_conditions` for later versions. Conditions need `json_schema_version` `:draft7` or later, or `:openapi31`; other versions raise `ArgumentError`.
- `condition ..., document_as: :one_of` documents a condition in a version as a `oneOf` of its branches in `to_schema`, while the validation schema keeps `if` / `then` / `else`. `then_apply` and `else_apply` take `title`, `description` and `deprecated` for their variant.

### Changed
- A `one_of` with a `discriminator:` keeps the discriminator in the validation schema. Its variants move into local `definitions` referenced by `$ref`, under a content-hash id written as both `$id` and `id` (`https://verquest.local/one_of/...`). With `json_schema_version = :openapi31` or `:openapi30`, validation errors come only from the variant the discriminator selects, and a missing, unknown or non-object value gets a single `discriminator` error. Under `:openapi30`, valid payloads that were rejected with `oneOf` errors (OpenAPI 3.0 has no `const`, so they matched every variant) now pass. Other versions validate as before, but `to_validation_schema` output changes. If you register these schemas with another validator, note the new ids.
- The transformer turns every mapping format into one plan built at initialization, and is frozen. `Verquest::NOT_FOUND` moved to `Verquest::Transformer::Path::NOT_FOUND`. In the mapping, `_variant_path` and `_nullable_path` hold the full source path inside collections too (`entries[]/content` instead of `content`).
- A `null` oneOf maps to `null` whether it has a discriminator or not, and inside multiple oneOfs.

### Fixed
- A `one_of` inside an `object` mapped a valid payload to an empty hash, and two of them clashed. It also works inside an object in a collection.
- Empty collection items are kept (they were dropped, or became `nil` before a later item), and a `null` nested object inside an item stays `null`.
- A `null` nullable oneOf with a nested `map:` (e.g. `"billing/payment"`) is written as a nested key, not as the literal key `"billing/payment"`.
- A collection item without its optional oneOf, or with a `null` nullable one, no longer raises "No matching schema found". A nullable oneOf without a discriminator in a collection can be defined (the duplicate-mapping check counted its metadata).
- Properties whose names start with `_` are mapped next to oneOfs and inverted in `external_mapping`.
- A collection with `map:` and a oneOf no longer nests every item under the collection name again, also when a variant's first property is moved out with `map: "/..."`.
- Without validation, a present oneOf without its discriminator raises "Missing discriminator" instead of mapping to an empty hash, and an unknown value raises in collection items too. A value naming a metadata key no longer crashes with `NoMethodError`.

## [0.6.3] - 2026-09-23

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

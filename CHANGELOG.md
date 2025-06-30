## [Unreleased]

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

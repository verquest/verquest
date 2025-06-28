## [Unreleased]

### New Features
- Add support for custom field types.

### Fixed
- Loading the gem in another project with `zeitwerk` now works correctly.

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

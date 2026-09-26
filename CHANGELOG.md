# Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.1.0] - 2026-09-26

### Added

- Record types `SRV`, `URI`, `HTTPS`, `SVCB`, `TLSA`, `SMIMEA`, `SSHFP`, `DS`, `DNSKEY`, `CERT`, `NAPTR` and `LOC` through the new `data` field, and `OPENPGPKEY` (provider v5)
- Validation of `data` fields for each record type
- `URI` records require `priority`

### Changed

- Wrapper tests cover only the mapping to the provider resource; record parsing is tested in the core module

## [2.0.0] - 2026-09-26

### Changed

- **Breaking:** records are keyed in the state by their content in the zone file format (`app A 30.40.50.60`, `www CNAME`, `_dmarc TXT 21541c4e7044`) instead of their position in the list, so adding, removing or reordering items no longer recreates other records. Existing states must be migrated, see "Upgrading from v1" in the README

### Added

- Optional `key` field to keep a record in place when its value changes
- Duplicate record keys fail at `plan` with the list of duplicates
- `state_migration` output mapping the 1.x keys to the new ones, used to generate `moved` blocks

## [1.1.0] - 2026-09-26

### Added

- Validation of the `records` input: supported record types, non-empty `content`, TTL range, `proxied` only for `A`/`AAAA`/`CNAME`/`ALIASES`, `priority` for `MX`, `tag` for `CAA`
- `records` output with `id`, `name`, `type` and `content` of each managed record
- Complete examples for provider v4 and v5 in `examples/`
- Tests for the core module and the examples
- Dependabot updates for GitHub Actions

### Changed

- README usage example starts with the zone apex (`@`)

## [1.0.0] - 2026-09-26

### Added

- Provider-agnostic core module `modules/dns/records`
- `modules/dns/v4` wrapper for Cloudflare provider v4 (`cloudflare_record`)
- `modules/dns/v5` wrapper for Cloudflare provider v5 (`cloudflare_dns_record`) with a `moved` block for migration from v4
- Optional `zone_name` input, looked up from `zone_id` when omitted
- Plan-only tests with a mocked provider
- CI: `terraform fmt`, `validate`, `test`, TFLint and Gitleaks

### Fixed

- The locals file was not loaded by Terraform
- Hardcoded root domain replaced with `zone_name` or a zone lookup
- Defaults for `ttl`, `proxied` and `flags` were `null` instead of the documented values
- Inline aliases pointed to a relative name instead of the full hostname
- Zone apex (`@`) handling for aliases and nested names

[Unreleased]: https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/compare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/releases/tag/v1.0.0

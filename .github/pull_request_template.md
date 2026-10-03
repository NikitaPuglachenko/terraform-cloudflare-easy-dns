## What and Why

<!-- The problem and how this change solves it; link the issue if there is one -->

## Checklist

- [ ] Tests for the new behavior or the fixed bug
- [ ] `terraform fmt`, `./scripts/check-sync.sh`, `./scripts/generate-docs.sh` and `scripts/generate-schema.py` are run
- [ ] The wrappers (`modules/dns/v4`, `modules/dns/v5`) and the root module have the same inputs and outputs
- [ ] Record keys do not change, or `moved` blocks and a migration note are added
- [ ] README and the `[Unreleased]` section of CHANGELOG.md are updated

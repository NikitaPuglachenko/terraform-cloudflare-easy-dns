# Contributing

Bug reports, questions and pull requests are welcome. For a larger change (a new input, record type or behavior), open an issue first, so we can agree on the design before you write the code.

Security problems are reported privately, see [SECURITY.md](SECURITY.md).

## Development Setup

- Terraform 1.8.5 or later (CI tests 1.8.5 and the latest version)
- [terraform-docs](https://terraform-docs.io) v0.24.0
- [TFLint](https://github.com/terraform-linters/tflint)
- Python 3 with `jsonschema` and `pyyaml`
- `shellcheck`, `jq`

The [Structure](README.md#structure) section of the README shows where the code lives. In short: the record logic is in `modules/dns/records`, the provider wrappers in `modules/dns/v4` and `modules/dns/v5`, and the root module passes everything to the v5 wrapper.

## Checks

Run the same checks as CI before you open a pull request:

```sh
terraform fmt -recursive
./scripts/check-sync.sh        # the root module and the wrappers have the same interface
./scripts/generate-docs.sh     # after changing variables, outputs or requirements
python3 scripts/generate-schema.py
python3 scripts/test-schema.py --terraform
tflint --init && tflint --recursive --config "$PWD/.tflint.hcl"

# in the changed module and its examples
terraform init -backend=false && terraform validate && terraform test
```

The plan-only tests use a mocked provider and need no Cloudflare credentials, see [Testing](README.md#testing). The end-to-end test needs a real zone; it runs weekly in CI, so you do not have to run it, but say in the pull request if your change affects how records are created, imported or migrated.

## Pull Requests

- Keep one change per pull request, with tests for new behavior and fixed bugs.
- Keep the wrappers in sync: a change of inputs or outputs goes into `modules/dns/v4`, `modules/dns/v5` and the root module.
- Changing a record key moves records in the state of every user. Avoid it, or add `moved` blocks and a note in [Upgrading and Migration](README.md#upgrading-and-migration).
- Add a line to the `[Unreleased]` section of [CHANGELOG.md](CHANGELOG.md) for changes users see.
- Update the README when the behavior or the inputs change.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By taking part, you agree to follow it.

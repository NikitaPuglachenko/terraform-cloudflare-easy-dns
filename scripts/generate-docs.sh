#!/usr/bin/env sh
# Regenerates the Terraform reference sections of the module READMEs.
# CI runs it and fails if the committed READMEs differ from the result.
set -eu

cd "$(dirname "$0")/.."

for dir in modules/dns/records modules/dns/v4 modules/dns/v5; do
  terraform-docs --config .terraform-docs.yml "$dir"
done

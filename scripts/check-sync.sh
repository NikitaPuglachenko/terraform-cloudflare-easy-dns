#!/usr/bin/env sh
# Checks that the copies of the module interface are the same: the root module
# repeats the variables and outputs of the v5 wrapper, and both wrappers share
# the records variable.
set -eu

cd "$(dirname "$0")/.."
status=0

if ! diff -u modules/dns/v5/variables.tf variables.tf; then
    echo "variables.tf differs from modules/dns/v5/variables.tf" >&2
    status=1
fi

outputs() { grep -E '^output ' "$1"; }
if [ "$(outputs modules/dns/v5/outputs.tf)" != "$(outputs outputs.tf)" ]; then
    echo "outputs.tf does not have the outputs of modules/dns/v5/outputs.tf" >&2
    status=1
fi

records() { awk '/^variable "records"/, /^}/' "$1"; }
if [ "$(records modules/dns/v4/variables.tf)" != "$(records modules/dns/v5/variables.tf)" ]; then
    echo "The records variable differs between modules/dns/v4 and modules/dns/v5" >&2
    status=1
fi
if [ "$(records modules/dns/records/variables.tf | awk '/^  validation/ { exit } { print }')" != "$(records modules/dns/v5/variables.tf | sed '$d')" ]; then
    echo "The records variable type differs between modules/dns/records and modules/dns/v5" >&2
    status=1
fi

[ "$status" -eq 0 ] && echo "Module interfaces are in sync"
exit "$status"

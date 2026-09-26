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
# The entry points accept records as any and check attribute names themselves; the
# allowed names must be the attributes of the typed records in the core module
core_attributes() { records modules/dns/records/variables.tf | sed -nE "s/^ {$1}([a-z0-9_]+) +=.*optional\(.*/\1/p" | sort; }
allowed() { grep -oE "\\[\"$1\"[^]]*\\]" modules/dns/v5/variables.tf | head -n 1 | grep -oE '[a-z0-9_]+' | sort; }
if [ "$(core_attributes 10)" != "$(allowed content)" ]; then
    echo "The allowed record attributes in modules/dns/v5/variables.tf differ from the records type of modules/dns/records" >&2
    status=1
fi
if [ "$(core_attributes 12)" != "$(allowed flatten_cname)" ]; then
    echo "The allowed settings attributes in modules/dns/v5/variables.tf differ from the records type of modules/dns/records" >&2
    status=1
fi

[ "$status" -eq 0 ] && echo "Module interfaces are in sync"
exit "$status"

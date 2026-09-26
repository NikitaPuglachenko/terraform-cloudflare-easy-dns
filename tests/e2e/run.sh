#!/usr/bin/env bash
# End-to-end test against a real Cloudflare zone: creates records of all types
# under a label of this run, checks updates, import and the v4 to v5 migration,
# and deletes everything at the end.
#
# Requires CLOUDFLARE_API_TOKEN (DNS Edit on the zone), E2E_ZONE_ID and E2E_ZONE_NAME.
set -euo pipefail

: "${CLOUDFLARE_API_TOKEN:?}" "${E2E_ZONE_ID:?}" "${E2E_ZONE_NAME:?}"
cd "$(dirname "$0")"
E2E_DIR=$(pwd)
LABEL="${E2E_LABEL:-e2e-$(date +%s)}"
export CLOUDFLARE_API_TOKEN E2E_ZONE_ID
export TF_VAR_zone_id="$E2E_ZONE_ID" TF_VAR_zone_name="$E2E_ZONE_NAME" TF_VAR_prefix="$LABEL"
export TF_IN_AUTOMATION=1 TF_INPUT=0

fail() {
    echo "FAIL: $*" >&2
    exit 1
}
pass() { echo "ok - $*"; }
tf() { terraform -chdir="${E2E_DIR}/$1" "${@:2}"; }

cleanup() {
    local rc=$?
    set +e
    for dir in v4to5 v4 v5; do
        [ -f "${E2E_DIR}/${dir}/terraform.tfstate" ] && tf "$dir" destroy -auto-approve -no-color >/dev/null
    done
    "${E2E_DIR}/sweep.sh" "$LABEL"
    rm -rf "${E2E_DIR}"/*/terraform.tfstate* "${E2E_DIR}"/*/tfplan
    exit "$rc"
}
trap cleanup EXIT

# Prints how many resources a saved plan creates, deletes, updates, imports and moves
plan_summary() {
    tf "$1" plan -no-color -out=tfplan "${@:2}" >/dev/null
    tf "$1" show -json tfplan | jq -r '
        [.resource_changes[]? | select(.mode == "managed")] as $rc |
        "create=\([$rc[] | select(.change.actions | index("create"))] | length) " +
        "delete=\([$rc[] | select(.change.actions | index("delete"))] | length) " +
        "update=\([$rc[] | select(.change.actions == ["update"])] | length) " +
        "import=\([$rc[] | select(.change.importing)] | length) " +
        "move=\([$rc[] | select(.previous_address and .previous_address != .address)] | length)"'
}

# Fails when the plan has any change: the provider would show a perpetual diff
assert_no_changes() {
    local rc=0
    tf "$1" plan -no-color -detailed-exitcode "${@:2}" >"${E2E_DIR}/plan.log" || rc=$?
    [ "$rc" -eq 0 ] || fail "$1: expected no changes, plan exit code $rc: $(grep -E '^  #|~ |\+ |- ' "${E2E_DIR}/plan.log" | head -40)"
}

echo "Label: ${LABEL}, zone: ${E2E_ZONE_NAME}"
"${E2E_DIR}/sweep.sh" --stale

for dir in v5 import v4 v4to5; do tf "$dir" init -no-color >/dev/null; done

# Scenario 1: create all record types, then check there is no drift
tf v5 apply -auto-approve -no-color >"${E2E_DIR}/apply.log" || fail "apply: $(tail -40 "${E2E_DIR}/apply.log")"
count=$(tf v5 state list | grep -c 'cloudflare_dns_record.record\[')
pass "created ${count} records of all types"
assert_no_changes v5
pass "no drift after apply"

# Changing a value without a key replaces the record, with a key updates it in place
summary=$(plan_summary v5 -var a_value=192.0.2.20 -var txt_value=rotation=2)
[ "$summary" = "create=1 delete=1 update=1 import=0 move=0" ] || fail "value changes: ${summary}"
tf v5 apply -auto-approve -no-color tfplan >/dev/null
assert_no_changes v5 -var a_value=192.0.2.20 -var txt_value=rotation=2
pass "value change: record without key replaced, record with key updated in place"

# Scenario 2: the same records are adopted into an empty state. Provider v5 plans a
# one-time update without visible changes for imported structured records (SRV, ...)
summary=$(plan_summary import -var a_value=192.0.2.20 -var txt_value=rotation=2)
case "$summary" in
    "create=0 delete=0 update="*" import=${count} move=0") ;;
    *) fail "import: ${summary}, expected import=${count} and nothing created or deleted" ;;
esac
tf import apply -auto-approve -no-color tfplan >/dev/null
assert_no_changes import -var a_value=192.0.2.20 -var txt_value=rotation=2
# The records stay managed by the state of scenario 1, which deletes them
rm -f "${E2E_DIR}/import/terraform.tfstate"*
pass "all ${count} records imported, no drift afterwards (${summary})"

# Scenario 3: records created with provider v4 are moved to v5 without recreation
tf v4 apply -auto-approve -no-color >"${E2E_DIR}/apply.log" || fail "v4 apply: $(tail -40 "${E2E_DIR}/apply.log")"
assert_no_changes v4
pass "provider v4: created records without drift"
cp "${E2E_DIR}/v4/terraform.tfstate" "${E2E_DIR}/v4to5/terraform.tfstate"
rm -f "${E2E_DIR}/v4/terraform.tfstate"
summary=$(plan_summary v4to5)
case "$summary" in
    "create=0 delete=0 "*) ;;
    *) fail "v4 to v5 migration: ${summary}" ;;
esac
# Provider v5 may report an inconsistent modified_on (different precision than in the
# migrated state) for some records on this first apply; the records are updated and
# the next plan is empty, so only this error is tolerated until
# https://github.com/cloudflare/terraform-provider-cloudflare/issues/7387 is fixed
only_modified_on_inconsistency() {
    local attributes
    grep -q "Provider produced inconsistent result after apply" "$1" || return 1
    attributes=$(grep -oE "unexpected new value: \.[a-z_]+" "$1" | sed 's/.*\.//' | sort -u)
    [ "$attributes" = "modified_on" ]
}
if ! tf v4to5 apply -auto-approve -no-color tfplan >"${E2E_DIR}/apply.log" 2>&1; then
    only_modified_on_inconsistency "${E2E_DIR}/apply.log" || fail "v4 to v5 apply: $(tail -40 "${E2E_DIR}/apply.log")"
    echo "note: provider reported the known modified_on inconsistency after the migration"
fi
assert_no_changes v4to5
pass "v4 to v5 migration without recreating records (${summary})"

echo "All end-to-end checks passed"

#!/usr/bin/env bash
# Deletes records left by end-to-end runs. Only records that have the comment
# "easy-dns-e2e" AND a name with an e2e run label are touched, so records managed
# otherwise in the zone are never deleted.
#
# Usage: sweep.sh <label>     records of one run (label e.g. e2e-123)
#        sweep.sh --stale     records of any run older than 3 hours
set -euo pipefail

: "${CLOUDFLARE_API_TOKEN:?}" "${E2E_ZONE_ID:?}"
api="https://api.cloudflare.com/client/v4/zones/${E2E_ZONE_ID}/dns_records"
auth=(-H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}")

records=$(curl -fsS "${auth[@]}" "${api}?comment.exact=easy-dns-e2e&per_page=5000000" | jq -c '.result[]')
[ -n "$records" ] || exit 0

if [ "${1:-}" = "--stale" ]; then
    cutoff=$(($(date +%s) - 3 * 3600))
    # $cutoff is a jq variable
    # shellcheck disable=SC2016
    filter='select(.name | test("(^|[.-])e2e-[0-9]+")) | select((.created_on | sub("\\.[0-9]+Z$"; "Z") | fromdate) < ($cutoff | tonumber))'
    selected=$(echo "$records" | jq -c --arg cutoff "$cutoff" "$filter")
else
    label="${1:?label or --stale}"
    [[ "$label" =~ ^e2e-[0-9a-z-]+$ ]] || { echo "Invalid label: $label" >&2; exit 1; }
    selected=$(echo "$records" | jq -c --arg label "$label" 'select(.name | contains($label))')
fi

[ -n "$selected" ] || exit 0
echo "$selected" | while read -r record; do
    id=$(echo "$record" | jq -r .id)
    echo "Deleting $(echo "$record" | jq -r '"\(.type) \(.name)"')"
    curl -fsS -X DELETE "${auth[@]}" "${api}/${id}" >/dev/null
done

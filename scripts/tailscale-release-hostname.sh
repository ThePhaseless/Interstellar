#!/usr/bin/env bash

# Frees a Tailscale hostname by deleting the stale device records still
# claiming it, so a rebuilt machine re-enrols as "talos-1" rather than
# "talos-1-1". Run this BEFORE the replacement enrols: Tailscale reuses node
# IDs, so deleting after re-auth can remove the machine that just joined.
#
# The devices API reports `online` as null, so staleness is judged on lastSeen.
# The most recently seen record is always kept, and nothing is deleted without
# --yes.

set -euo pipefail

usage() {
    echo "Usage: $0 <hostname> [--yes] [--min-age-hours N]" >&2
    echo "  Lists records claiming <hostname> or <hostname>-N, keeping the" >&2
    echo "  most recently seen one. Without --yes this is a dry run." >&2
}

target="${1:-}"
[[ -z "$target" || "$target" == -* ]] && { usage; exit 1; }
shift

confirm="no"
min_age_hours=24
while [[ $# -gt 0 ]]; do
    case "$1" in
    --yes) confirm="yes"; shift ;;
    --min-age-hours) min_age_hours="$2"; shift 2 ;;
    *) usage; exit 1 ;;
    esac
done

: "${TF_VAR_tailscale_oauth_client_id:?source scripts/setup-env.sh first}"
: "${TF_VAR_tailscale_oauth_secret:?source scripts/setup-env.sh first}"

token=$(curl -sf -u "${TF_VAR_tailscale_oauth_client_id}:${TF_VAR_tailscale_oauth_secret}" \
    -d 'grant_type=client_credentials' \
    https://api.tailscale.com/api/v2/oauth/token | jq -r '.access_token')
[[ -n "$token" && "$token" != "null" ]] || { echo "Failed to mint access token." >&2; exit 1; }

devices=$(curl -sf -H "Authorization: Bearer ${token}" \
    "https://api.tailscale.com/api/v2/tailnet/-/devices") ||
    { echo "Failed to list devices." >&2; exit 1; }

matches=$(echo "$devices" | jq -c --arg t "$target" '
    [ .devices[]
      | {id, name, lastSeen, addresses}
      | . + {short: (.name | split(".")[0])}
      | select(.short == $t or (.short | test("^" + $t + "-[0-9]+$"))) ]
    | sort_by(.lastSeen) | reverse')

count=$(echo "$matches" | jq 'length')
if [[ "$count" -eq 0 ]]; then
    echo "No records claiming '${target}'."
    exit 0
fi

echo "Records claiming '${target}' (newest first):"
echo "$matches" | jq -r '.[] | "  \(.short)  lastSeen=\(.lastSeen)  id=\(.id)"'

# Keep index 0 (most recently seen). Everything older than the threshold is stale.
cutoff=$(date -u -d "${min_age_hours} hours ago" +%Y-%m-%dT%H:%M:%SZ)
stale=$(echo "$matches" | jq -c --arg cutoff "$cutoff" '.[1:][] | select(.lastSeen < $cutoff)')

if [[ -z "$stale" ]]; then
    echo
    echo "Nothing stale: keeping the newest record, and no other record is older than ${min_age_hours}h."
    exit 0
fi

echo
echo "Stale (older than ${min_age_hours}h, not the newest):"
echo "$stale" | jq -r '"  \(.short)  lastSeen=\(.lastSeen)  id=\(.id)"'

if [[ "$confirm" != "yes" ]]; then
    echo
    echo "Dry run. Re-run with --yes to delete these."
    exit 0
fi

echo "$stale" | jq -r '.id' | while read -r id; do
    curl -sf -X DELETE -H "Authorization: Bearer ${token}" \
        "https://api.tailscale.com/api/v2/device/${id}" >/dev/null
    echo "  deleted ${id}"
done

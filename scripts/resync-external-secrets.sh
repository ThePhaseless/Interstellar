#!/usr/bin/env bash
# Usage: ./scripts/resync-external-secrets.sh [namespace]
#   [namespace]  Optional namespace to scope the resync (default: all namespaces)
#
# Forces all Bitwarden-backed ExternalSecrets to immediately re-fetch from
# Bitwarden Secrets Manager by bumping a refresh annotation on each object.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

NAMESPACE="${1:-}"

if [[ -n "$NAMESPACE" ]]; then
    NS_ARGS="-n $NAMESPACE"
    echo -e "${YELLOW}Resyncing ExternalSecrets in namespace: ${NAMESPACE}${NC}"
else
    NS_ARGS="--all-namespaces"
    echo -e "${YELLOW}Resyncing ExternalSecrets across all namespaces${NC}"
fi

SECRETS=$(kubectl get externalsecret $NS_ARGS -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"')

if [[ -z "$SECRETS" ]]; then
    echo -e "${YELLOW}No ExternalSecrets found.${NC}"
    exit 0
fi

SUCCESS=0
FAIL=0

while IFS= read -r entry; do
    ns="${entry%%/*}"
    name="${entry##*/}"
    echo -n "  Resyncing ${ns}/${name} ... "
    if kubectl annotate externalsecret "$name" -n "$ns" \
        force.refresh.force.external-secrets.io/v1="$(date +%s)" \
        --overwrite > /dev/null 2>&1; then
        echo -e "${GREEN}ok${NC}"
        (( ++SUCCESS ))
    else
        echo -e "${RED}failed${NC}"
        (( ++FAIL ))
    fi
done <<< "$SECRETS"

echo ""
echo -e "${GREEN}Done: ${SUCCESS} resynced${NC}${FAIL:+, }${FAIL:+${RED}${FAIL} failed${NC}}"
[[ $FAIL -eq 0 ]]

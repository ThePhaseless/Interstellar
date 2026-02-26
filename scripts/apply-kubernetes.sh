#!/usr/bin/env bash
# Usage: ./scripts/apply-kubernetes.sh <path>
#   <path>  Path to a directory containing kustomization.yaml

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [[ $# -ne 1 ]]; then
    echo -e "${RED}Usage: $0 <kustomize-directory>${NC}"
    echo "  e.g. $0 Kubernetes/bootstrap/metallb"
    exit 1
fi

TARGET_PATH="$1"

if [[ ! -d "$TARGET_PATH" ]]; then
    echo -e "${RED}Error: directory not found: ${TARGET_PATH}${NC}"
    exit 1
fi

if [[ ! -f "$TARGET_PATH/kustomization.yaml" && ! -f "$TARGET_PATH/kustomization.yml" ]]; then
    echo -e "${RED}Error: no kustomization.yaml found in ${TARGET_PATH}${NC}"
    exit 1
fi

for cmd in kubectl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}Error: ${cmd} not found in PATH${NC}"
        exit 1
    fi
done

KUSTOMIZE_CMD=""
if command -v kustomize &>/dev/null; then
    KUSTOMIZE_CMD="kustomize build --enable-helm"
else
    KUSTOMIZE_CMD="kubectl kustomize"
fi

echo -e "${GREEN}Applying ${TARGET_PATH}${NC}"

echo -e "${YELLOW}Building manifests${NC}"
TMPFILE=$(mktemp)
trap 'rm -f "${TMPFILE}"' EXIT INT TERM

if ! ${KUSTOMIZE_CMD} "${TARGET_PATH}" >"${TMPFILE}" 2>&1; then
    echo -e "${RED}kustomize build failed. Output:${NC}"
    sed -n '1,200p' "${TMPFILE}" >&2 || true
    exit 1
fi

OBJECT_COUNT=$(grep -c '^kind:' "${TMPFILE}" || true)
echo -e "${YELLOW}Applying ${OBJECT_COUNT} objects${NC}"

MAX_RETRIES=3
for attempt in $(seq 1 $MAX_RETRIES); do
    if kubectl apply --server-side --force-conflicts -f "${TMPFILE}"; then
        break
    fi
    if [[ $attempt -lt $MAX_RETRIES ]]; then
        echo -e "${YELLOW}Apply failed (attempt ${attempt}/${MAX_RETRIES}); retrying in 15s${NC}"
        sleep 15
    else
        echo -e "${RED}Apply failed after ${MAX_RETRIES} attempts${NC}"
        sed -n '1,200p' "${TMPFILE}" >&2 || true
        exit 1
    fi
done

echo -e "${GREEN}Done${NC}"

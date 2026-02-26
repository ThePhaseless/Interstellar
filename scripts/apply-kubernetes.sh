#!/usr/bin/env bash
# =============================================================================
# Kubernetes Kustomize Apply
# =============================================================================
# Builds a Kustomize directory (with Helm support) and applies it to the
# cluster using server-side apply with force-conflicts.
#
# Usage: ./scripts/apply-kubernetes.sh <path>
#   <path>  Path to a directory containing kustomization.yaml
#
# Examples:
#   ./scripts/apply-kubernetes.sh Kubernetes/bootstrap/metallb
#   ./scripts/apply-kubernetes.sh Kubernetes/apps

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Validate arguments
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
for cmd in kubectl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}Error: ${cmd} not found in PATH${NC}"
        exit 1
    fi
done

# Prefer standalone `kustomize` when available, otherwise fall back to `kubectl kustomize`.
KUSTOMIZE_CMD=""
if command -v kustomize &>/dev/null; then
    KUSTOMIZE_CMD="kustomize build --enable-helm"
else
    KUSTOMIZE_CMD="kubectl kustomize"
fi

# ---------------------------------------------------------------------------
# Build & Apply (with retries for CRD ordering)
# ---------------------------------------------------------------------------
echo -e "${GREEN}=== Applying ${TARGET_PATH} ===${NC}"

echo -e "${YELLOW}Building manifests...${NC}"
# Use a temp file so large manifests don't get mangled and so we can retry safely.
TMPFILE=$(mktemp)
trap 'rm -f "${TMPFILE}"' EXIT INT TERM

if ! ${KUSTOMIZE_CMD} "${TARGET_PATH}" >"${TMPFILE}" 2>&1; then
    echo -e "${RED}kustomize build failed. Output:${NC}"
    sed -n '1,200p' "${TMPFILE}" >&2 || true
    exit 1
fi

OBJECT_COUNT=$(grep -c '^kind:' "${TMPFILE}" || true)
echo -e "${YELLOW}Applying ${OBJECT_COUNT} objects...${NC}"

MAX_RETRIES=3
for attempt in $(seq 1 $MAX_RETRIES); do
    if kubectl apply --server-side --force-conflicts -f "${TMPFILE}"; then
        break
    fi
    if [[ $attempt -lt $MAX_RETRIES ]]; then
        echo -e "${YELLOW}Apply had errors (attempt ${attempt}/${MAX_RETRIES}). Waiting 15s for CRDs to establish before retrying...${NC}"
        sleep 15
    else
        echo -e "${RED}Apply failed after ${MAX_RETRIES} attempts. Showing last 200 lines of manifests for diagnosis:${NC}"
        sed -n '1,200p' "${TMPFILE}" >&2 || true
        exit 1
    fi
done

echo -e "${GREEN}=== Done ===${NC}"

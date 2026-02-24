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
for cmd in kustomize kubectl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}Error: ${cmd} not found in PATH${NC}"
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Build & Apply
# ---------------------------------------------------------------------------
echo -e "${GREEN}=== Applying ${TARGET_PATH} ===${NC}"

echo -e "${YELLOW}Building manifests...${NC}"
MANIFESTS=$(kustomize build --enable-helm "$TARGET_PATH")

OBJECT_COUNT=$(echo "$MANIFESTS" | grep -c '^kind:' || true)
echo -e "${YELLOW}Applying ${OBJECT_COUNT} objects...${NC}"

echo "$MANIFESTS" | kubectl apply --server-side --force-conflicts -f -

echo -e "${GREEN}=== Done ===${NC}"

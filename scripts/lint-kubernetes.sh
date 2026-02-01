#!/usr/bin/env bash
# =============================================================================
# Kubernetes Manifest Linter
# =============================================================================
# This script runs kube-linter on the Kubernetes manifests to catch issues
# before deployment. It's designed to be run in CI/CD or locally.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
K8S_DIR="${REPO_ROOT}/Kubernetes"
CONFIG_FILE="${REPO_ROOT}/.kube-linter.yaml"

# Ensure kube-linter is available
if ! command -v kube-linter &> /dev/null; then
    # Try adding Go bin to PATH
    export PATH="/home/vscode/go/bin:${PATH}"
    if ! command -v kube-linter &> /dev/null; then
        echo -e "${RED}Error: kube-linter not found in PATH${NC}"
        echo "Install with: go install golang.stackrox.io/kube-linter/cmd/kube-linter@latest"
        exit 1
    fi
fi

echo -e "${GREEN}=== Kubernetes Manifest Linter ===${NC}"
echo -e "Repository root: ${REPO_ROOT}"
echo -e "Kubernetes dir:  ${K8S_DIR}"
echo -e "Config file:     ${CONFIG_FILE}"
echo ""

# Check if directory exists
if [[ ! -d "${K8S_DIR}" ]]; then
    echo -e "${RED}Error: Kubernetes directory not found: ${K8S_DIR}${NC}"
    exit 1
fi

# Check if config exists
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo -e "${YELLOW}Warning: Config file not found, using defaults${NC}"
    CONFIG_ARG=""
else
    CONFIG_ARG="--config=${CONFIG_FILE}"
fi

echo -e "${YELLOW}Running kube-linter...${NC}"
echo ""

# Find all YAML files and lint them
# kube-linter doesn't recurse into subdirectories properly, so we find all yaml files
YAML_FILES=$(find "${K8S_DIR}" -type f \( -name "*.yaml" -o -name "*.yml" \) ! -name "kustomization.yaml" | sort)

if [[ -z "${YAML_FILES}" ]]; then
    echo -e "${YELLOW}Warning: No YAML files found to lint${NC}"
    exit 0
fi

echo -e "Found $(echo "${YAML_FILES}" | wc -l) YAML files to lint"
echo ""

# Run kube-linter on all found YAML files
LINT_RESULT=0
echo "${YAML_FILES}" | xargs kube-linter lint \
    ${CONFIG_ARG} \
    --format=plain \
    || LINT_RESULT=$?

echo ""

if [[ ${LINT_RESULT} -eq 0 ]]; then
    echo -e "${GREEN}✓ All Kubernetes manifests passed linting!${NC}"
else
    echo -e "${RED}✗ Linting found issues. Please fix them before deployment.${NC}"
    exit ${LINT_RESULT}
fi

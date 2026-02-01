#!/usr/bin/env bash
# OpenTofu Linter Script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOFU_DIR="${REPO_ROOT}/OpenTofu"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if ! command -v tflint &> /dev/null; then
    echo -e "${RED}Error: tflint not found${NC}"
    echo "Install with: curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash"
    exit 1
fi

echo -e "${GREEN}=== OpenTofu Linter ===${NC}"
echo "OpenTofu dir: ${TOFU_DIR}"

cd "${TOFU_DIR}"

echo "Initializing plugins..."
tflint --init

echo ""
echo "Running tflint..."
if tflint --format=compact; then
    echo -e "${GREEN}✓ All OpenTofu files passed linting!${NC}"
else
    echo -e "${RED}✗ Linting found issues${NC}"
    exit 1
fi

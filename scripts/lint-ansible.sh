#!/usr/bin/env bash
# Ansible Linter Script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${REPO_ROOT}/Ansible"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if ! command -v ansible-lint &> /dev/null; then
    echo -e "${RED}Error: ansible-lint not found${NC}"
    echo "Install with: uv tool install ansible-lint"
    exit 1
fi

echo -e "${GREEN}=== Ansible Linter ===${NC}"
echo "Ansible dir: ${ANSIBLE_DIR}"

cd "${REPO_ROOT}"

# Skip dependency checks since roles/collections may not be installed locally
export ANSIBLE_LINT_NODEPS=1

echo "Running ansible-lint..."
if ansible-lint "${ANSIBLE_DIR}"; then
    echo -e "${GREEN}✓ All Ansible files passed linting!${NC}"
else
    echo -e "${RED}✗ Linting found issues${NC}"
    exit 1
fi

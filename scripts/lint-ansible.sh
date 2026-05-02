#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${REPO_ROOT}/Ansible"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if ! command -v ansible-lint &>/dev/null; then
    echo -e "${RED}Error: ansible-lint not found${NC}"
    echo "Run 'mise run install' to sync the project's Python dependencies into .venv."
    exit 1
fi

echo -e "${GREEN}Ansible lint${NC}"
echo "Ansible dir: ${ANSIBLE_DIR}"

cd "${REPO_ROOT}"

if python -c 'import yaml; import sys; sys.exit(0 if hasattr(yaml, "cyaml") else 1)' 2>/dev/null; then
    :
else
    echo "PyYAML libyaml support missing; continuing with the pure-Python loader."
fi

export ANSIBLE_LINT_NODEPS=1

echo "Running ansible-lint..."
if [[ -f "${ANSIBLE_DIR}/requirements.yaml" ]]; then
    echo "Installing Ansible collections/roles (requirements.yaml)..."
    ansible-galaxy install -r "${ANSIBLE_DIR}/requirements.yaml"
fi
if ansible-lint "${ANSIBLE_DIR}"; then
    echo -e "${GREEN}✓ All Ansible files passed linting!${NC}"
else
    echo -e "${RED}✗ Linting found issues${NC}"
    exit 1
fi

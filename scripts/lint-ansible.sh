#!/usr/bin/env bash
# Ansible Linter Script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${REPO_ROOT}/Ansible"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if ! command -v ansible-lint &>/dev/null; then
    echo -e "${RED}Error: ansible-lint not found${NC}"
    echo "Install with: uv tool install ansible-lint"
    exit 1
fi

echo -e "${GREEN}=== Ansible Linter ===${NC}"
echo "Ansible dir: ${ANSIBLE_DIR}"

cd "${REPO_ROOT}"

# ansible-core 2.20+ can fail to parse YAML (including .ansible-lint) when
# PyYAML is installed without its libyaml extension.
if python -c 'import yaml; import sys; sys.exit(0 if hasattr(yaml, "cyaml") else 1)' 2>/dev/null; then
    :
else
    echo "PyYAML libyaml support missing; installing PyYAML 6.0.2 wheel..."
    if command -v uv &>/dev/null; then
        uv pip install --only-binary :all: "pyyaml==6.0.2" || {
            echo -e "${RED}Error: could not install PyYAML 6.0.2 wheel.${NC}"
            echo "Hint: use Python 3.13 for this repo (see .python-version)."
            exit 1
        }
    else
        echo -e "${RED}Error: uv not found (needed to install PyYAML wheel)${NC}"
        exit 1
    fi
fi

# Skip dependency checks since roles/collections may not be installed locally
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

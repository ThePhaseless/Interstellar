#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
K8S_DIR="${REPO_ROOT}/Kubernetes"
CONFIG_FILE="${REPO_ROOT}/.kube-linter.yaml"
MIN_KUSTOMIZE_VERSION="v5.8.1"

version_ge() {
    local left="${1#v}"
    local right="${2#v}"
    [[ "$(printf '%s\n' "$left" "$right" | sort -V | head -n1)" == "$right" ]]
}

if ! command -v kube-linter &>/dev/null; then
    export PATH="/home/vscode/go/bin:${PATH}"
    if ! command -v kube-linter &>/dev/null; then
        echo -e "${RED}Error: kube-linter not found in PATH${NC}"
        echo "Install with: go install golang.stackrox.io/kube-linter/cmd/kube-linter@latest"
        exit 1
    fi
fi

echo -e "${GREEN}Kubernetes manifest lint${NC}"
echo -e "Repository root: ${REPO_ROOT}"
echo -e "Kubernetes dir:  ${K8S_DIR}"
echo -e "Config file:     ${CONFIG_FILE}"
echo ""

if ! command -v kustomize &>/dev/null; then
    echo -e "${RED}Error: standalone kustomize not found in PATH${NC}"
    echo "Install kustomize >= ${MIN_KUSTOMIZE_VERSION} to support Helm v4 with --enable-helm"
    exit 1
fi

KUSTOMIZE_VERSION_RAW="$(kustomize version 2>/dev/null || true)"
KUSTOMIZE_VERSION="$(echo "${KUSTOMIZE_VERSION_RAW}" | grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"

if [[ -z "${KUSTOMIZE_VERSION}" ]]; then
    echo -e "${RED}Error: could not parse kustomize version output: ${KUSTOMIZE_VERSION_RAW}${NC}"
    exit 1
fi

if ! version_ge "${KUSTOMIZE_VERSION}" "${MIN_KUSTOMIZE_VERSION}"; then
    echo -e "${RED}Error: kustomize ${KUSTOMIZE_VERSION} is too old${NC}"
    echo "Required: >= ${MIN_KUSTOMIZE_VERSION}"
    exit 1
fi

echo -e "Using standalone kustomize: ${KUSTOMIZE_VERSION}"
echo ""

if [[ ! -d "${K8S_DIR}" ]]; then
    echo -e "${RED}Error: Kubernetes directory not found: ${K8S_DIR}${NC}"
    exit 1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo -e "${YELLOW}Warning: Config file not found, using defaults${NC}"
    CONFIG_ARG=""
else
    CONFIG_ARG="--config=${CONFIG_FILE}"
fi

echo -e "${YELLOW}Validating kustomizations with standalone kustomize --enable-helm...${NC}"
KUSTOMIZATION_DIRS=$(find "${K8S_DIR}" -type f -name "kustomization.yaml" -exec dirname {} \; | sort)

KUSTOMIZE_RESULT=0
while IFS= read -r kustomization_dir; do
    [[ -z "${kustomization_dir}" ]] && continue
    rel_dir="${kustomization_dir#${REPO_ROOT}/}"
    echo "- Building ${rel_dir}"
    kustomize build --enable-helm "${kustomization_dir}" >/dev/null || KUSTOMIZE_RESULT=1
done <<<"${KUSTOMIZATION_DIRS}"

if [[ ${KUSTOMIZE_RESULT} -ne 0 ]]; then
    echo ""
    echo -e "${RED}✗ Kustomize build validation failed.${NC}"
    exit ${KUSTOMIZE_RESULT}
fi

echo ""

echo -e "${YELLOW}Running kube-linter...${NC}"
echo ""

YAML_FILES=$(find "${K8S_DIR}" -type f \( -name "*.yaml" -o -name "*.yml" \) ! -name "kustomization.yaml" | sort)

if [[ -z "${YAML_FILES}" ]]; then
    echo -e "${YELLOW}Warning: No YAML files found to lint${NC}"
    exit 0
fi

echo -e "Found $(echo "${YAML_FILES}" | wc -l) YAML files to lint"
echo ""

LINT_RESULT=0
echo "${YAML_FILES}" | xargs kube-linter lint \
    ${CONFIG_ARG} \
    --format=plain ||
    LINT_RESULT=$?

echo ""

if [[ ${LINT_RESULT} -eq 0 ]]; then
    echo -e "${GREEN}✓ All Kubernetes manifests passed linting!${NC}"
else
    echo -e "${RED}✗ Linting found issues. Please fix them before deployment.${NC}"
    exit ${LINT_RESULT}
fi

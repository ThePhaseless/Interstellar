#!/usr/bin/env bash
# =============================================================================
# Local Environment Setup Script
# =============================================================================
# This script sets up environment variables for running Terraform and Ansible
# locally. It fetches secrets from Bitwarden and exports them.
#
# Prerequisites:
#   1. Tailscale installed and authenticated
#   2. Bitwarden CLI (bws) installed
#   3. BWS_ACCESS_TOKEN environment variable set
#
# Usage:
#   source scripts/setup-env.sh
#
# After sourcing, you can run:
#   cd Terraform && terraform init && terraform plan
#   cd Ansible && ansible-playbook -i inventory setup-proxmox.yaml
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------------------------
# Fetch a single secret and export it
# -----------------------------------------------------------------------------
fetch_and_export_secret() {
    local bws_name="$1"
    local env_name="$2"
    local value

    value=$(bws secret get "$bws_name" --output json 2>/dev/null | jq -r '.value' 2>/dev/null)
    if [[ $? -eq 0 && "$value" != "null" && -n "$value" ]]; then
        export "$env_name"="$value"
        return 0
    fi

    log_warn "Failed to fetch secret: $bws_name"
    return 1
}

# -----------------------------------------------------------------------------
# Fetch a batch of secrets and return collective exit status
# -----------------------------------------------------------------------------
fetch_batch() {
    if (( $# % 2 != 0 )); then
        log_error "fetch_batch: Expected an even number of arguments (pairs of BWS_NAME ENV_NAME)"
        return 1
    fi

    local status=0
    while [[ $# -gt 0 ]]; do
        fetch_and_export_secret "$1" "$2" || status=1
        shift 2
    done
    return $status
}

# -----------------------------------------------------------------------------
# Load .env file if it exists
# -----------------------------------------------------------------------------
load_env_file() {
    if [[ -f ".env" ]]; then
        log_info "Loading .env file..."
        # shellcheck disable=SC1091
        set -a
        source .env
        set +a
        log_success ".env file loaded"
    fi
}

# -----------------------------------------------------------------------------
# Check prerequisites
# -----------------------------------------------------------------------------
check_prerequisites() {
    local missing=0

    # Check Tailscale
    if ! command -v tailscale &>/dev/null; then
        log_error "Tailscale CLI not found. Install from https://tailscale.com/download"
        missing=1
    elif ! tailscale status &>/dev/null; then
        log_error "Tailscale not connected. Run: tailscale up"
        missing=1
    else
        log_success "Tailscale connected"
    fi

    # Check Bitwarden CLI
    if ! command -v bws &>/dev/null; then
        log_error "Bitwarden CLI (bws) not found. Install from https://bitwarden.com/help/secrets-manager-cli/"
        missing=1
    else
        log_success "Bitwarden CLI found"
    fi

    # Check jq
    if ! command -v jq &>/dev/null; then
        log_error "jq not found. Install with: sudo apt install jq"
        missing=1
    else
        log_success "jq found"
    fi

    # Check BWS_ACCESS_TOKEN
    if [[ -z "${BWS_ACCESS_TOKEN:-}" ]]; then
        log_error "BWS_ACCESS_TOKEN environment variable not set."
        log_info "Get your access token from Bitwarden Secrets Manager."
        missing=1
    else
        log_success "BWS_ACCESS_TOKEN is set"
    fi

    if [[ $missing -eq 1 ]]; then
        return 1
    fi

    log_success "All prerequisites met"
    return 0
}

# -----------------------------------------------------------------------------
# Fetch secrets from Bitwarden and export as environment variables
# -----------------------------------------------------------------------------
fetch_secrets() {
    log_info "Fetching secrets from Bitwarden..."

    # OCI Backend secrets (for Terraform state)
    log_info "Fetching OCI backend secrets..."
    fetch_batch \
        "oci-tenancy-ocid" "OCI_tenancy_ocid" \
        "oci-user-ocid" "OCI_user_ocid" \
        "oci-fingerprint" "OCI_fingerprint" \
        "oci-private-key" "OCI_private_key" \
        "oci-region" "OCI_region" \
        "oci-namespace" "TF_VAR_oci_namespace" \
        "tf-state-bucket" "TF_STATE_BUCKET"

    if [[ $? -eq 0 ]]; then
        log_success "OCI backend secrets loaded"
    else
        log_warn "Some OCI backend secrets are missing. Terraform state operations may fail."
    fi

    # Infrastructure secrets (for Terraform apply)
    log_info "Fetching infrastructure secrets..."
    fetch_batch \
        "tailscale-tailnet" "TF_VAR_tailscale_tailnet" \
        "oci-compartment-id" "TF_VAR_oci_compartment_id"

    if [[ $? -eq 0 ]]; then
        log_success "Infrastructure secrets loaded"
    else
        log_warn "Some infrastructure secrets are missing."
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    log_info "=== Local Environment Setup ==="
    echo ""

    load_env_file

    if ! check_prerequisites; then
        log_error "Prerequisites check failed. Please fix the issues above."
        return 1
    fi

    fetch_secrets

    echo ""
    log_success "Environment ready!"
    echo ""
    log_info "You can now run:"
    echo "  cd Terraform && terraform init && terraform plan"
    echo "  cd Ansible && ansible-playbook setup-proxmox.yaml"
    echo ""
}

# Run the setup
main

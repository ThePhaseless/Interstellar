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
    
    # Use subshells to avoid killing the parent shell on failure
    local tenancy=$(bws secret get oci-tenancy-ocid --output json 2>/dev/null | jq -r '.value' || echo "")
    local user=$(bws secret get oci-user-ocid --output json 2>/dev/null | jq -r '.value' || echo "")
    local fingerprint=$(bws secret get oci-fingerprint --output json 2>/dev/null | jq -r '.value' || echo "")
    local key=$(bws secret get oci-private-key --output json 2>/dev/null | jq -r '.value' || echo "")
    local region=$(bws secret get oci-region --output json 2>/dev/null | jq -r '.value' || echo "")
    local namespace=$(bws secret get oci-namespace --output json 2>/dev/null | jq -r '.value' || echo "")

    if [[ -n "$tenancy" ]]; then
        export OCI_tenancy_ocid="$tenancy"
        export OCI_user_ocid="$user"
        export OCI_fingerprint="$fingerprint"
        export OCI_private_key="$key"
        export OCI_region="$region"
        export TF_VAR_oci_namespace="$namespace"
        log_success "OCI backend secrets loaded"
    else
        log_warn "Could not fetch OCI backend secrets. Terraform state operations may fail."
    fi

    # Infrastructure secrets (for Terraform apply)
    log_info "Fetching infrastructure secrets..."
    local tailnet=$(bws secret get tailscale-tailnet --output json 2>/dev/null | jq -r '.value' || echo "")
    local compartment=$(bws secret get oci-compartment-id --output json 2>/dev/null | jq -r '.value' || echo "")

    if [[ -n "$tailnet" ]]; then
        export TF_VAR_tailscale_tailnet="$tailnet"
        export TF_VAR_oci_compartment_id="$compartment"
        log_success "Infrastructure secrets loaded"
    else
        log_warn "Could not fetch some infrastructure secrets"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    log_info "=== Local Environment Setup ==="
    echo ""

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

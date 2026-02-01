#!/usr/bin/env bash
# =============================================================================
# Local Environment Setup Script
# =============================================================================
# This script sets up environment variables for running OpenTofu and Ansible
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
#   cd Terraform && tofu init && tofu plan
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
# Fetch a single secret by key name and export it
# -----------------------------------------------------------------------------
fetch_and_export_secret() {
    local bws_name="$1"
    local env_name="$2"
    local value

    value=$(bws secret list --output json 2>/dev/null | jq -r --arg key "$bws_name" '.[] | select(.key == $key) | .value' 2>/dev/null)
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

    # OCI config file and private key
    log_info "Setting up OCI config..."
    local oci_config oci_private_key secrets_json

    # Fetch all secrets once for efficiency
    secrets_json=$(bws secret list --output json 2>/dev/null)

    oci_config=$(echo "$secrets_json" | jq -r '.[] | select(.key == "oci-config") | .value' 2>/dev/null)
    oci_private_key=$(echo "$secrets_json" | jq -r '.[] | select(.key == "oci-private-key") | .value' 2>/dev/null)

    if [[ -n "$oci_config" && "$oci_config" != "null" ]]; then
        mkdir -p "$HOME/.oci"
        printf "%s" "$oci_config" > "$HOME/.oci/config"
        printf "%s" "$oci_private_key" > "$HOME/.oci/oci_api_key.pem"
        chmod 600 "$HOME/.oci/config" "$HOME/.oci/oci_api_key.pem"

        # Update key_file path in config
        if grep -q '^key_file=' "$HOME/.oci/config"; then
            sed -i "s|^key_file=.*|key_file=$HOME/.oci/oci_api_key.pem|" "$HOME/.oci/config"
        else
            echo "key_file=$HOME/.oci/oci_api_key.pem" >> "$HOME/.oci/config"
        fi

        # Extract tenancy for OpenTofu variable
        local tenancy
        tenancy=$(grep -E '^tenancy=' "$HOME/.oci/config" | head -n1 | cut -d= -f2-)
        if [[ -n "$tenancy" ]]; then
            export TF_VAR_oci_tenancy_ocid="$tenancy"
        fi
        log_success "OCI config written to ~/.oci/config"
    else
        log_warn "OCI config not found in Bitwarden. OCI operations may fail."
    fi

    # Other OCI secrets
    fetch_batch \
        "oci-namespace" "TF_VAR_oci_namespace" \
        "tf-state-bucket" "TF_STATE_BUCKET"

    if [[ $? -eq 0 ]]; then
        log_success "OCI backend secrets loaded"
    else
        log_warn "Some OCI backend secrets are missing. OpenTofu state operations may fail."
    fi

    # Infrastructure secrets (for OpenTofu apply)
    log_info "Fetching infrastructure secrets..."

    fetch_batch \
        "tailscale-tailnet" "TF_VAR_tailscale_tailnet" \
        "cloudflare-api-token" "CLOUDFLARE_API_TOKEN" \
        "cloudflare-zone-id" "TF_VAR_cloudflare_zone_id" \
        "proxmox-api-token" "PROXMOX_VE_API_TOKEN"

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
    echo "  cd Terraform && tofu init && tofu plan"
    echo "  cd Ansible && ansible-playbook setup-proxmox.yaml"
    echo ""
}

# Run the setup
main

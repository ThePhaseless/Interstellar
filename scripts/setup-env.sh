#!/usr/bin/env bash

# =============================================================================
# Local Environment Setup Script
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------------------------
# Sanitize JSON
# -----------------------------------------------------------------------------
sanitize_json() {
    # Delete control chars, keep tabs/newlines
    tr -cd '[:print:]\t\n'
}

# -----------------------------------------------------------------------------
# Check prerequisites
# -----------------------------------------------------------------------------
check_prerequisites() {
    local missing=0

    for cmd in tailscale bws jq grep cut sed; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Command not found: $cmd"
            missing=1
        fi
    done

    if [[ -z "${BWS_ACCESS_TOKEN:-}" ]]; then
        log_error "BWS_ACCESS_TOKEN environment variable is not set."
        missing=1
    fi

    [[ $missing -eq 1 ]] && return 1
    return 0
}

# -----------------------------------------------------------------------------
# Fetch Bitwarden Secrets Manager Organization ID (CORRECT WAY)
# -----------------------------------------------------------------------------
fetch_bws_org_id() {
    local org_id

    org_id=$(
        bws project list --output json --color no 2>/dev/null |
            sanitize_json |
            jq -r '.[0].organizationId // empty'
    )

    if [[ -z "$org_id" ]]; then
        log_error "Failed to determine Bitwarden Secrets Manager Organization ID via bws project."
        return 1
    fi

    export BW_ORGANIZATION_ID="$org_id"
    export BWS_ORGANIZATION_ID="$org_id"

    log_success "Bitwarden Organization ID set"
}

# -----------------------------------------------------------------------------
# Fetch a single secret and export it
# -----------------------------------------------------------------------------
fetch_and_export_secret() {
    local bws_key="$1"
    local env_var_name="$2"
    local value=""

    # 1. Try cache
    if [[ -n "${SECRETS_JSON:-}" ]]; then
        value=$(echo "$SECRETS_JSON" |
            jq -r --arg key "$bws_key" '.[] | select(.key == $key) | .value' 2>/dev/null)
    fi

    # 2. Fallback to CLI
    if [[ -z "$value" || "$value" == "null" ]]; then
        value=$(
            bws secret list --output json --color no 2>/dev/null |
                sanitize_json |
                jq -r --arg key "$bws_key" '.[] | select(.key == $key) | .value' 2>/dev/null
        )
    fi

    if [[ -n "$value" && "$value" != "null" ]]; then
        export "$env_var_name"="$value"
        return 0
    fi

    log_warn "Secret not found or empty: $bws_key"
    return 1
}

# -----------------------------------------------------------------------------
# Fetch multiple secrets
# -----------------------------------------------------------------------------
fetch_batch() {
    local exit_code=0

    while [[ $# -gt 0 ]]; do
        fetch_and_export_secret "$1" "$2" || exit_code=1
        shift 2
    done

    return $exit_code
}

# -----------------------------------------------------------------------------
# OCI Setup
# -----------------------------------------------------------------------------
setup_oci() {
    log_info "Configuring OCI..."

    mkdir -p "$HOME/.oci"
    local config_path="$HOME/.oci/config"
    local key_path="$HOME/.oci/oci_api_key.pem"

    local oci_config_content
    local oci_key_content

    oci_config_content=$(
        bws secret list --output json --color no 2>/dev/null |
            sanitize_json |
            jq -r '.[] | select(.key == "oci-config") | .value' 2>/dev/null
    )

    oci_key_content=$(
        bws secret list --output json --color no 2>/dev/null |
            sanitize_json |
            jq -r '.[] | select(.key == "oci-private-key") | .value' 2>/dev/null
    )

    if [[ -z "$oci_config_content" || "$oci_config_content" == "null" ]]; then
        log_warn "OCI config secret not found."
        return 1
    fi

    touch "$config_path" "$key_path"
    chmod 600 "$config_path" "$key_path"

    printf "%s\n" "$oci_config_content" >"$config_path"
    printf "%s\n" "$oci_key_content" >"$key_path"

    if grep -q '^key_file=' "$config_path" 2>/dev/null; then
        sed -i "s|^key_file=.*|key_file=$key_path|" "$config_path"
    else
        echo "key_file=$key_path" >>"$config_path"
    fi

    export OCI_TENANCY_OCID=$(grep '^tenancy=' "$config_path" | cut -d= -f2 | tr -d ' "' || true)
    export OCI_USER_OCID=$(grep '^user=' "$config_path" | cut -d= -f2 | tr -d ' "' || true)
    export OCI_FINGERPRINT=$(grep '^fingerprint=' "$config_path" | cut -d= -f2 | tr -d ' "' || true)
    export OCI_REGION=$(grep '^region=' "$config_path" | cut -d= -f2 | tr -d ' "' || true)

    export TF_VAR_oci_tenancy_ocid="$OCI_TENANCY_OCID"
    export OCI_PRIVATE_KEY="$oci_key_content"

    log_success "OCI configuration written"
}

# -----------------------------------------------------------------------------
# Talos Setup
# -----------------------------------------------------------------------------
setup_talosconfig() {
    log_info "Configuring Talos client..."

    local talosconfig_content=""
    local talos_dir="$HOME/.talos"
    local talos_config_path="$talos_dir/config"

    if [[ -n "${SECRETS_JSON:-}" ]]; then
        talosconfig_content=$(echo "$SECRETS_JSON" |
            jq -r '.[] | select(.key == "talosconfig") | .value' 2>/dev/null)
    fi

    if [[ -z "$talosconfig_content" || "$talosconfig_content" == "null" ]]; then
        talosconfig_content=$(
            bws secret list --output json --color no 2>/dev/null |
                sanitize_json |
                jq -r '.[] | select(.key == "talosconfig") | .value' 2>/dev/null
        )
    fi

    if [[ -z "$talosconfig_content" || "$talosconfig_content" == "null" ]]; then
        log_warn "Talosconfig secret not found. Skipping ~/.talos/config setup."
        return 1
    fi

    mkdir -p "$talos_dir"
    chmod 700 "$talos_dir"
    printf "%s\n" "$talosconfig_content" >"$talos_config_path"
    chmod 600 "$talos_config_path"

    log_success "Talos client config written to ~/.talos/config"
}

# -----------------------------------------------------------------------------
# kubectl Setup via Tailscale
# -----------------------------------------------------------------------------
setup_kubeconfig() {
    log_info "Configuring kubectl context via Tailscale..."

    local kubeconfig_target="${TS_KUBECONFIG_TARGET:-talos-1}"

    if ! command -v tailscale &>/dev/null; then
        log_warn "tailscale CLI not found. Skipping kubeconfig setup."
        return 1
    fi

    if ! tailscale status &>/dev/null; then
        log_warn "Tailscale is not connected. Skipping kubeconfig setup."
        return 1
    fi

    if tailscale configure kubeconfig "$kubeconfig_target" >/dev/null 2>&1; then
        log_success "kubectl context configured from Tailscale ($kubeconfig_target)"
        return 0
    fi

    log_warn "Failed to configure kubectl context via Tailscale for '$kubeconfig_target'."
    return 1
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log_info "=== Local Environment Setup ==="

    if [[ -f ".env" ]]; then
        set -a
        source .env
        set +a
        log_info "Loaded .env file"
    fi

    check_prerequisites || return 1

    export BW_ACCESS_TOKEN="$BWS_ACCESS_TOKEN"

    log_info "Fetching Bitwarden secrets..."
    SECRETS_JSON=$(bws secret list --output json --color no 2>/dev/null | sanitize_json)

    if [[ -z "$SECRETS_JSON" || "$SECRETS_JSON" == "[]" ]]; then
        log_error "Bitwarden returned no secrets. Check your token."
        return 1
    fi

    fetch_bws_org_id || return 1
    setup_oci
    setup_talosconfig
    setup_kubeconfig

    fetch_batch \
        "oci-namespace" "TF_VAR_oci_namespace" \
        "tf-state-bucket" "TF_STATE_BUCKET" \
        "tailscale-tailnet" "TF_VAR_tailscale_tailnet" \
        "cloudflare-api-token" "CLOUDFLARE_API_TOKEN" \
        "cloudflare-zone-id" "TF_VAR_cloudflare_zone_id" \
        "proxmox-api-token" "PROXMOX_VE_API_TOKEN"

    echo ""
    log_success "Environment ready!"
}

main

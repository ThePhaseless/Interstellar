#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

sanitize_json() {
    tr -cd '[:print:]\t\n'
}

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

fetch_and_export_secret() {
    local bws_key="$1"
    local env_var_name="$2"
    local value=""

    if [[ -n "${SECRETS_JSON:-}" ]]; then
        value=$(printf '%s' "$SECRETS_JSON" |
            jq -r --arg key "$bws_key" '.[] | select(.key == $key) | .value' 2>/dev/null)
    fi

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

fetch_batch() {
    local exit_code=0

    while [[ $# -gt 0 ]]; do
        fetch_and_export_secret "$1" "$2" || exit_code=1
        shift 2
    done

    return $exit_code
}

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

    OCI_TENANCY_OCID=$(grep '^tenancy=' "$config_path" | cut -d= -f2 | tr -d ' "' || true)
    export OCI_TENANCY_OCID
    OCI_USER_OCID=$(grep '^user=' "$config_path" | cut -d= -f2 | tr -d ' "' || true)
    export OCI_USER_OCID
    OCI_FINGERPRINT=$(grep '^fingerprint=' "$config_path" | cut -d= -f2 | tr -d ' "' || true)
    export OCI_FINGERPRINT
    OCI_REGION=$(grep '^region=' "$config_path" | cut -d= -f2 | tr -d ' "' || true)
    export OCI_REGION

    export TF_VAR_oci_tenancy_ocid="$OCI_TENANCY_OCID"
    export OCI_PRIVATE_KEY="$oci_key_content"

    log_success "OCI configuration written"
}

main() {
    log_info "Local environment setup"

    local script_dir
    local _src=""
    if [ -n "${BASH_SOURCE[0]+x}" ] && [ -n "${BASH_SOURCE[0]}" ]; then
        _src="${BASH_SOURCE[0]}"
    elif [ -n "${funcfiletrace[1]+x}" ]; then
        _src="${funcfiletrace[1]%:*}"
    fi
    script_dir="$(cd "$(dirname "$(readlink -f "$_src")")" && pwd)"
    local repo_root
    repo_root="$(cd "${script_dir}/.." && pwd)"
    local env_file="${repo_root}/.env"

    log_info "Searching for .env file at: ${env_file}"

    if [[ -f "$env_file" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "$env_file"
        set +a
        log_info "Loaded .env file from ${repo_root}"
    fi

    check_prerequisites || return 1

    export BW_ACCESS_TOKEN="$BWS_ACCESS_TOKEN"
    export TF_VAR_bws_access_token="$BWS_ACCESS_TOKEN"

    log_info "Fetching Bitwarden secrets..."
    SECRETS_JSON=$(bws secret list --output json --color no 2>/dev/null | sanitize_json)

    if [[ -z "$SECRETS_JSON" || "$SECRETS_JSON" == "[]" ]]; then
        log_error "Bitwarden returned no secrets. Check your token."
        return 1
    fi

    fetch_bws_org_id || return 1
    setup_oci

    fetch_batch \
        "oci-namespace" "TF_VAR_oci_namespace" \
        "tailscale-tailnet" "TF_VAR_tailscale_tailnet" \
        "tailscale-oracle-auth-key" "TAILSCALE_ORACLE_AUTH_KEY" \
        "cloudflare-api-token" "CLOUDFLARE_API_TOKEN" \
        "cloudflare-zone-id" "TF_VAR_cloudflare_zone_id" \
        "hcloud-token" "HCLOUD_TOKEN"

    local px_user
    local px_token_id
    local px_api_token
    px_user=$(printf '%s' "$SECRETS_JSON" | jq -r '.[] | select(.key == "proxmox-user") | .value' 2>/dev/null)
    px_token_id=$(printf '%s' "$SECRETS_JSON" | jq -r '.[] | select(.key == "proxmox-token-id") | .value' 2>/dev/null)
    px_api_token=$(printf '%s' "$SECRETS_JSON" | jq -r '.[] | select(.key == "proxmox-api-token") | .value' 2>/dev/null)
    if [[ -n "$px_user" && -n "$px_token_id" && -n "$px_api_token" && "$px_user" != "null" && "$px_token_id" != "null" && "$px_api_token" != "null" ]]; then
        export PROXMOX_VE_API_TOKEN="${px_user}!${px_token_id}=${px_api_token}"
    fi

    if [[ -n "${HCLOUD_TOKEN:-}" ]]; then
        export TF_VAR_hcloud_token="$HCLOUD_TOKEN"
    fi

    export KUBE_CONFIG_PATH="${KUBE_CONFIG_PATH:-$HOME/.kube/config}"

    local vip_raw=""
    vip_raw=$(printf '%s' "$SECRETS_JSON" |
        jq -r '.[] | select(.key == "authentik-vip-emails") | .value' 2>/dev/null)
    if [[ -n "$vip_raw" && "$vip_raw" != "null" ]]; then
        export TF_VAR_authentik_vip_emails="$vip_raw"
    fi

    log_success "Environment ready!"
}

main

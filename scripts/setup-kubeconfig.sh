#!/usr/bin/env bash
# Usage: ./scripts/setup-kubeconfig.sh
# Sets up talosconfig (~/.talos/config) and kubeconfig (~/.kube/config)
# by fetching the talosconfig from Bitwarden Secrets Manager
# and generating kubeconfig via talosctl.
#
# Prerequisites:
#   - BWS_ACCESS_TOKEN set (or source scripts/setup-env.sh first)
#   - bws, jq, talosctl available in PATH
#   - Node reachable via Tailscale MagicDNS

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TALOS_DIR="${HOME}/.talos"
TALOS_CONFIG="${TALOS_DIR}/config"
KUBE_DIR="${HOME}/.kube"
KUBE_CONFIG="${KUBE_DIR}/config"

# Check required commands
for cmd in bws jq talosctl; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: $cmd"
        exit 1
    fi
done

# Auto-load BWS_ACCESS_TOKEN from .env if not set
if [[ -z "${BWS_ACCESS_TOKEN:-}" ]]; then
    env_file="${REPO_ROOT}/.env"
    if [[ -f "$env_file" ]]; then
        log_info "Loading .env file..."
        set -a
        # shellcheck disable=SC1090
        source "$env_file"
        set +a
    fi
fi

if [[ -z "${BWS_ACCESS_TOKEN:-}" ]]; then
    log_error "BWS_ACCESS_TOKEN is not set."
    log_error "Set it via: export BWS_ACCESS_TOKEN=<token>  or  echo 'BWS_ACCESS_TOKEN=\"<token>\"' > .env"
    exit 1
fi

# --- Talosconfig ---
log_info "Fetching talosconfig from Bitwarden Secrets Manager..."

talosconfig_value=$(
    bws secret list --output json --color no 2>/dev/null |
        tr -cd '[:print:]\t\n' |
        jq -r '.[] | select(.key == "talosconfig") | .value' 2>/dev/null
)

if [[ -z "$talosconfig_value" || "$talosconfig_value" == "null" ]]; then
    log_error "Secret 'talosconfig' not found in Bitwarden. Has Terraform been applied?"
    exit 1
fi

mkdir -p "$TALOS_DIR"
chmod 700 "$TALOS_DIR"

printf '%s\n' "$talosconfig_value" > "$TALOS_CONFIG"
chmod 600 "$TALOS_CONFIG"
log_success "Talosconfig written to ${TALOS_CONFIG}"

# --- Extract node for kubeconfig generation ---
# Use the first endpoint from the talosconfig to find a reachable node via MagicDNS.
# The talosconfig context name is the cluster name.
bootstrap_node=$(talosctl config info --output json 2>/dev/null | jq -r '.nodes[0] // .endpoints[0] // empty' 2>/dev/null || true)

if [[ -z "$bootstrap_node" ]]; then
    # Fallback: parse endpoints directly from the YAML
    bootstrap_node=$(jq -r '.contexts | to_entries[0].value.endpoints[0] // empty' <<< "$(yq -o=json '.' "$TALOS_CONFIG" 2>/dev/null)" 2>/dev/null || true)
fi

# Resolve via Tailscale MagicDNS: try node names from talosconfig
# The Terraform config sets nodes to LAN IPs; we need MagicDNS names for Tailscale access.
# Extract the first node name from Bitwarden or use known convention.
talos_node=""
tailscale_domain=""

# Try to get the MagicDNS domain from the talosconfig (endpoints may be IPs or FQDNs)
if [[ -n "$bootstrap_node" ]]; then
    if [[ "$bootstrap_node" =~ \.ts\.net$ ]]; then
        # Already a MagicDNS FQDN
        talos_node="$bootstrap_node"
    else
        # It's a LAN IP — resolve via Tailscale MagicDNS
        # Get the MagicDNS domain
        if command -v tailscale &>/dev/null; then
            tailscale_domain=$(tailscale status --json 2>/dev/null | jq -r '.MagicDNSSuffix // empty' 2>/dev/null || true)
        fi

        if [[ -n "$tailscale_domain" ]]; then
            # Try to find the node name by matching the IP in tailscale status
            ts_node_name=$(tailscale status --json 2>/dev/null | jq -r --arg ip "$bootstrap_node" '
                .Peer | to_entries[] |
                select(.value.TailscaleIPs[]? == $ip or (.value.HostName | test("talos"))) |
                .value.HostName' 2>/dev/null | head -1 || true)

            if [[ -n "$ts_node_name" ]]; then
                talos_node="${ts_node_name}.${tailscale_domain}"
            else
                # Default to talos-1 (first sorted node name from Terraform)
                talos_node="talos-1.${tailscale_domain}"
                log_warn "Could not resolve node name from Tailscale, defaulting to ${talos_node}"
            fi
        else
            # No Tailscale CLI — fall back to LAN IP
            talos_node="$bootstrap_node"
            log_warn "Tailscale not available, using LAN IP: ${talos_node}"
        fi
    fi
else
    # No node found in talosconfig at all — use default
    if command -v tailscale &>/dev/null; then
        tailscale_domain=$(tailscale status --json 2>/dev/null | jq -r '.MagicDNSSuffix // empty' 2>/dev/null || true)
    fi
    if [[ -z "$tailscale_domain" ]]; then
        log_error "No node found in talosconfig and Tailscale MagicDNS domain could not be determined."
        exit 1
    fi
    talos_node="talos-1.${tailscale_domain}"
    log_warn "No node found in talosconfig, defaulting to ${talos_node}"
fi

# --- Resolve Tailscale IP ---
# talosctl needs both -e (endpoint) and -n (node) overridden to the Tailscale IP,
# because the talosconfig stores LAN IPs which are unreachable remotely.
talos_ip=$(getent hosts "$talos_node" 2>/dev/null | awk '{print $1}')
if [[ -z "$talos_ip" ]]; then
    talos_ip="$talos_node"  # Fallback: use the hostname directly
fi

# --- Kubeconfig ---
log_info "Generating kubeconfig via talosctl (node: ${talos_node}, ip: ${talos_ip})..."

mkdir -p "$KUBE_DIR"
chmod 700 "$KUBE_DIR"

if talosctl -e "$talos_ip" -n "$talos_ip" kubeconfig "$KUBE_CONFIG" --force 2>/dev/null; then
    chmod 600 "$KUBE_CONFIG"
    # Patch the kubeconfig server: talosctl writes the cluster VIP (LAN IP),
    # replace it with the Tailscale IP so kubectl works remotely.
    sed -i "s|server: https://[0-9.]\+:6443|server: https://${talos_ip}:6443|" "$KUBE_CONFIG"
    log_success "Kubeconfig written to ${KUBE_CONFIG}"
else
    log_error "Failed to generate kubeconfig. Is the node reachable?"
    log_info "  Ensure Tailscale is connected and the cluster is running."
    log_info "  You can try manually: talosctl -e ${talos_ip} -n ${talos_ip} kubeconfig ${KUBE_CONFIG}"
    exit 1
fi

# --- Verify ---
log_info "Verifying cluster access..."

if kubectl --kubeconfig "$KUBE_CONFIG" get nodes &>/dev/null; then
    log_success "Cluster is reachable!"
    kubectl --kubeconfig "$KUBE_CONFIG" get nodes -o wide
else
    log_warn "Could not reach the cluster via kubectl. The kubeconfig was written but the API server may not be reachable from this machine."
fi

log_success "Setup complete!"
log_info "  Talosconfig: ${TALOS_CONFIG}"
log_info "  Kubeconfig:  ${KUBE_CONFIG}"

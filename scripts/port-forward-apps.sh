#!/usr/bin/env bash
# =============================================================================
# Port-forward Kubernetes services required by Terraform apps/
#
# Usage: ./scripts/port-forward-apps.sh
# Press Ctrl+C to stop all port-forwards.
# =============================================================================
set -euo pipefail

# Services: name namespace service_name local_port remote_port
SERVICES=(
    "sonarr    media  sonarr-tailscale  8989 8989"
    "radarr    media  radarr            7878 7878"
    "prowlarr  media  prowlarr          9696 9696"
    "adguard   home   adguard           3000 3000"
)

PIDS=()

cleanup() {
    echo ""
    echo "Stopping all port-forwards..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null
    echo "All port-forwards stopped."
}

trap cleanup EXIT INT TERM

# Reconnect loop: restarts port-forward if the process dies
port_forward_loop() {
    local name="$1" namespace="$2" svc="$3" local_port="$4" remote_port="$5"
    while true; do
        echo "[$name] Forwarding localhost:$local_port -> svc/$svc:$remote_port (ns: $namespace)"
        kubectl port-forward -n "$namespace" "svc/$svc" "$local_port:$remote_port" 2>&1 || true
        echo "[$name] Port-forward died, reconnecting in 3s..."
        sleep 3
    done
}

for entry in "${SERVICES[@]}"; do
    read -r name namespace svc local_port remote_port <<<"$entry"
    port_forward_loop "$name" "$namespace" "$svc" "$local_port" "$remote_port" &
    PIDS+=($!)
done

echo ""
echo "All port-forwards active (auto-reconnect enabled). Press Ctrl+C to stop."
echo ""

wait

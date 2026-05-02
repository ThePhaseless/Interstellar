#!/usr/bin/env bash
# Usage: ./scripts/port-forward-apps.sh
set -euo pipefail

SERVICES=(
    "sonarr    media     sonarr           8989 8989"
    "radarr    media     radarr           7878 7878"
    "prowlarr  media     prowlarr         9696 9696"
    "adguard   home      adguard          3000 3000"
    "authentik authentik authentik-server 9000 80"
)

KUBECTL_REQUEST_TIMEOUT="${KUBECTL_REQUEST_TIMEOUT:-10s}"

PIDS=()

cleanup() {
    echo "Stopping port-forwards..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null
    echo "Stopped."
}

trap cleanup EXIT INT TERM

port_forward_loop() {
    local name="$1" namespace="$2" svc="$3" local_port="$4" remote_port="$5"
    while true; do
        echo "[$name] Forwarding localhost:$local_port -> svc/$svc:$remote_port (ns: $namespace)"
        kubectl --request-timeout="$KUBECTL_REQUEST_TIMEOUT" port-forward -n "$namespace" "svc/$svc" "$local_port:$remote_port" 2>&1 || true
        echo "[$name] Port-forward died, reconnecting in 3s..."
        sleep 3
    done
}

for entry in "${SERVICES[@]}"; do
    read -r name namespace svc local_port remote_port <<<"$entry"
    port_forward_loop "$name" "$namespace" "$svc" "$local_port" "$remote_port" &
    PIDS+=($!)
done

echo "Port-forwards active. Ctrl+C to stop."

wait

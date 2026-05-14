#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 [--json|--shell]" >&2
}

output_format="json"
if [[ $# -gt 1 ]]; then
    usage
    exit 1
fi

if [[ $# -eq 1 ]]; then
    case "$1" in
        --json)
            ;;
        --shell)
            output_format="shell"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
fi

for cmd in curl jq tailscale; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing required command: $cmd" >&2
        exit 1
    fi
done

tailscale_status_json="$(tailscale status --json)"
magicdns_domain="$(jq -r '.MagicDNSSuffix // empty' <<<"$tailscale_status_json")"

if [[ -z "$magicdns_domain" ]]; then
    echo "Could not determine Tailscale MagicDNS domain" >&2
    exit 1
fi

mapfile -t talos_hosts < <(
    jq -r '
        .Peer
        | to_entries[]
        | .value.HostName // empty
        | select(startswith("talos-"))
    ' <<<"$tailscale_status_json" | sort -u
)

if [[ ${#talos_hosts[@]} -eq 0 ]]; then
    echo "No Talos hosts were found in tailscale status output" >&2
    exit 1
fi

selected_host=""
selected_ip=""

for short_host in "${talos_hosts[@]}"; do
    ip="$(jq -r --arg host "$short_host" '
        .Peer
        | to_entries[]
        | select(.value.HostName == $host)
        | .value.TailscaleIPs[]?
        | select(test(":") | not)
    ' <<<"$tailscale_status_json" | head -n 1)"

    if [[ -z "$ip" || "$ip" == "null" ]]; then
        continue
    fi

    fqdn="${short_host}.${magicdns_domain}"
    http_code="$(curl -sk --max-time 5 --resolve "${fqdn}:6443:${ip}" -o /dev/null -w '%{http_code}' "https://${fqdn}:6443/version" || true)"

    if [[ "$http_code" != "000" ]]; then
        selected_host="$fqdn"
        selected_ip="$ip"
        break
    fi
done

if [[ -z "$selected_host" || -z "$selected_ip" ]]; then
    echo "Could not find a reachable Talos Kubernetes API endpoint over Tailscale" >&2
    exit 1
fi

if [[ "$output_format" == "shell" ]]; then
    printf 'TALOS_API_HOST=%q\n' "$selected_host"
    printf 'TALOS_API_IP=%q\n' "$selected_ip"
else
    jq -n --arg host "$selected_host" --arg ip "$selected_ip" '{host: $host, ip: $ip}'
fi

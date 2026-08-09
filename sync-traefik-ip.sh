#!/bin/bash
# Keep traefik.fold-hen.ts.net resolvable on the Oracle VPS without MagicDNS.
#
# The VPS runs tailscale with --accept-dns=false (security decision, see
# AGENTS.md), so its tailscaled does not serve DNS and HAProxy cannot resolve
# MagicDNS names through 100.100.100.100. This script reads traefik's current
# tailnet IP from `tailscale status` (no DNS required), writes it into
# /etc/hosts, and SIGHUPs HAProxy so it re-parses its config and re-resolves
# the backend name via libc.
#
# Runs every 60s via traefik-ip-sync.timer. Idempotent; exits 0 when no
# change is needed.
set -euo pipefail

IP=$(tailscale status | awk '$2 == "traefik" { print $1; exit }')
if [ -z "$IP" ]; then
    echo "traefik peer not found in tailscale status" >&2
    exit 1
fi

LINE="$IP traefik.fold-hen.ts.net"
if grep -Fqx "$LINE" /etc/hosts; then
    exit 0
fi

# Replace any stale entry for the name (newest write wins; entry appended last).
sed -i '/ traefik\.fold-hen\.ts\.net$/d' /etc/hosts
echo "$LINE" >> /etc/hosts

# Reload HAProxy so it re-resolves the backend name. Container may be in
# restart backoff — ignore failures, the next tick retries.
docker kill -s HUP haproxy 2>/dev/null || true

#!/usr/bin/env python3
"""Dynamic Ansible inventory from Tailscale network status.

Queries 'tailscale status --json' and maps Tailscale device tags to
Ansible host groups.  Each device's first Tailscale IPv4 address is
used as ansible_host so connections work from anywhere on the tailnet
(including GitHub Actions runners).

Tag → Group mapping (configure TAG_GROUP_MAP below):
    tag:proxmox  → proxmox
    tag:oracle   → oracle, oracle_proxy   (first oracle host is proxy)
    tag:cluster  → cluster

Usage:
    ansible-inventory -i inventory_tailscale.py --list
    ansible-playbook -i inventory_tailscale.py playbook.yaml
"""

from __future__ import annotations

import json
import subprocess
import sys

# ── Configuration ────────────────────────────────────────────────────────────
# Map Tailscale tags to Ansible groups.  A device can appear in several groups
# if its tag matches multiple entries.
TAG_GROUP_MAP: dict[str, list[str]] = {
    "tag:proxmox": ["proxmox"],
    "tag:oracle": ["oracle"],
    "tag:cluster": ["cluster"],
}

# Ansible variables applied to every host
GLOBAL_HOST_VARS: dict[str, str] = {
    "ansible_user": "root",
}

# Per-group variable overrides (merged on top of GLOBAL_HOST_VARS)
GROUP_VARS: dict[str, dict[str, str]] = {
    "oracle": {
        "ansible_user": "ubuntu",
        "ansible_ssh_private_key_file": "~/.ssh/oracle_ed25519",
    },
}

# Oracle sub-groups: first oracle host becomes oracle_proxy
ORACLE_SUBGROUPS = True
# ── End configuration ────────────────────────────────────────────────────────


def tailscale_status() -> dict:
    """Run 'tailscale status --json' and return parsed JSON."""
    result = subprocess.run(
        ["tailscale", "status", "--json"],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)


def first_ipv4(ips: list[str]) -> str | None:
    """Return the first IPv4 address from a list of IPs."""
    for ip in ips:
        if "." in ip:
            return ip
    return None


def build_inventory() -> dict:
    """Build Ansible inventory dict from Tailscale status."""
    status = tailscale_status()
    peers: dict = status.get("Peer", {})

    # Collect hosts per group
    groups: dict[str, list[str]] = {}
    hostvars: dict[str, dict] = {}

    for _key, peer in peers.items():
        tags: list[str] = peer.get("Tags", [])
        if not tags:
            continue

        # Use the MagicDNS short name (strip trailing dot + tailnet suffix)
        dns_name: str = peer.get("DNSName", "")
        hostname = dns_name.split(".")[0] if dns_name else peer.get("HostName", "unknown")
        if not hostname:
            continue

        ip = first_ipv4(peer.get("TailscaleIPs", []))
        if not ip:
            continue

        # Skip offline peers
        if not peer.get("Online", False):
            continue

        host_vars = dict(GLOBAL_HOST_VARS)
        host_vars["ansible_host"] = ip

        matched = False
        for tag in tags:
            if tag in TAG_GROUP_MAP:
                matched = True
                for group in TAG_GROUP_MAP[tag]:
                    groups.setdefault(group, [])
                    if hostname not in groups[group]:
                        groups[group].append(hostname)

                    # Merge group-specific vars
                    for g in TAG_GROUP_MAP[tag]:
                        if g in GROUP_VARS:
                            host_vars.update(GROUP_VARS[g])

        if matched:
            hostvars[hostname] = host_vars

    # Build oracle sub-groups (first host = proxy, rest = compute)
    if ORACLE_SUBGROUPS and "oracle" in groups:
        oracle_hosts = groups["oracle"]
        if oracle_hosts:
            groups["oracle_proxy"] = [oracle_hosts[0]]
        if len(oracle_hosts) > 1:
            groups["oracle_compute"] = oracle_hosts[1:]

    # Build Ansible JSON inventory
    inventory: dict = {"_meta": {"hostvars": hostvars}}
    for group, hosts in groups.items():
        inventory[group] = {"hosts": hosts}

    return inventory


def main() -> None:
    """Entry point – supports --list and --host flags."""
    if len(sys.argv) == 2 and sys.argv[1] == "--list":
        print(json.dumps(build_inventory(), indent=2))
    elif len(sys.argv) == 3 and sys.argv[1] == "--host":
        # Single-host mode – return hostvars for the given host
        inventory = build_inventory()
        host = sys.argv[2]
        hostvars = inventory.get("_meta", {}).get("hostvars", {}).get(host, {})
        print(json.dumps(hostvars, indent=2))
    else:
        print("Usage: inventory_tailscale.py --list | --host <hostname>", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

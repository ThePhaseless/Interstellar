#!/usr/bin/env python3
"""Dynamic Ansible inventory built from 'tailscale status --json'.

Each device's first Tailscale IPv4 address is used as ansible_host so connections
work from anywhere on the tailnet, including GitHub Actions runners.
"""

from __future__ import annotations

import json
import subprocess
import sys

TAG_GROUP_MAP: dict[str, list[str]] = {
    "tag:proxmox": ["proxmox"],
    "tag:node": ["cluster"],
}

GLOBAL_HOST_VARS: dict[str, str] = {
    "ansible_user": "root",
}

GROUP_VARS: dict[str, dict[str, str]] = {
    "personal": {
        "ansible_user": "ubuntu",
        "ansible_ssh_private_key_file": "~/.ssh/oracle_ed25519",
    },
}

PERSONAL_HOSTNAMES = ("compute",)


def tailscale_status() -> dict:
    result = subprocess.run(
        ["tailscale", "status", "--json"],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)


def first_ipv4(ips: list[str]) -> str | None:
    for ip in ips:
        if "." in ip:
            return ip
    return None


def build_inventory() -> dict:
    status = tailscale_status()
    peers: dict = status.get("Peer", {})

    groups: dict[str, list[str]] = {}
    hostvars: dict[str, dict] = {}

    for peer in peers.values():
        tags: list[str] = peer.get("Tags", [])
        peer_hostname: str = peer.get("HostName", "")
        is_personal = peer_hostname in PERSONAL_HOSTNAMES
        if not tags and not is_personal:
            continue

        dns_name: str = peer.get("DNSName", "")
        hostname = dns_name.split(".")[0] if dns_name else peer_hostname or "unknown"
        if not hostname:
            continue

        ip = first_ipv4(peer.get("TailscaleIPs", []))
        if not ip:
            continue

        if not peer.get("Online", False):
            continue

        host_vars = dict(GLOBAL_HOST_VARS)
        host_vars["ansible_host"] = ip

        matched = is_personal
        if is_personal:
            groups.setdefault("personal", [])
            if hostname not in groups["personal"]:
                groups["personal"].append(hostname)
            host_vars.update(GROUP_VARS["personal"])

        for tag in tags:
            if tag in TAG_GROUP_MAP:
                matched = True
                for group in TAG_GROUP_MAP[tag]:
                    groups.setdefault(group, [])
                    if hostname not in groups[group]:
                        groups[group].append(hostname)

                    for g in TAG_GROUP_MAP[tag]:
                        if g in GROUP_VARS:
                            host_vars.update(GROUP_VARS[g])

        if matched:
            hostvars[hostname] = host_vars

    inventory: dict = {"_meta": {"hostvars": hostvars}}
    for group, hosts in groups.items():
        inventory[group] = {"hosts": hosts}

    return inventory


def main() -> None:
    if len(sys.argv) == 2 and sys.argv[1] == "--list":
        print(json.dumps(build_inventory(), indent=2))
    elif len(sys.argv) == 3 and sys.argv[1] == "--host":
        inventory = build_inventory()
        host = sys.argv[2]
        hostvars = inventory.get("_meta", {}).get("hostvars", {}).get(host, {})
        print(json.dumps(hostvars, indent=2))
    else:
        print(
            "Usage: inventory_tailscale.py --list | --host <hostname>", file=sys.stderr
        )
        sys.exit(1)


if __name__ == "__main__":
    main()

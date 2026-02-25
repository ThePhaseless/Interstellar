# =============================================================================
# AdGuard Home Configuration
# =============================================================================
# Manages AdGuard Home DNS settings via Terraform

# The AdGuard pod is a cluster workload (tag:cluster), NOT a Tailscale device.
# Tailscale's 100.100.100.100 resolver only works from Tailscale devices, so
# MagicDNS hostnames cannot be used as CNAME answers — AdGuard returns SERVFAIL.
# Use standard public resolvers only.
resource "adguard_config" "main" {
  dns = {
    upstream_dns = [
      "https://1.1.1.1/dns-query",
      "https://1.0.0.1/dns-query",
    ]
  }
}

# Direct Tailscale IP rewrite for non-LAN clients (Tailscale clients get the proxy pod IP).
# CNAME approach abandoned: AdGuard pod cannot resolve tag:k8s MagicDNS hostnames
# via 100.100.100.100 (cluster pods are not Tailscale devices → SERVFAIL).
# IP is stable as long as the traefik proxy pod secret is not deleted.
# Update var.traefik_tailscale_ip if the traefik device is ever re-registered.
resource "adguard_rewrite" "nerine_dev_wildcard" {
  domain = "*.nerine.dev"
  answer = var.traefik_tailscale_ip
}

resource "adguard_rewrite" "nerine_dev" {
  domain = "nerine.dev"
  answer = var.traefik_tailscale_ip
}

# Client-specific override → MetalLB IP for local LAN clients (user rules take priority over rewrites)
resource "adguard_user_rules" "nerine_dev_local" {
  rules = [
    "||nerine.dev^$dnsrewrite=NOERROR;A;${var.adguard_traefik_local_ip},client=192.168.0.0/16",
    "||*.nerine.dev^$dnsrewrite=NOERROR;A;${var.adguard_traefik_local_ip},client=192.168.0.0/16",
  ]
}

resource "adguard_list_filter" "adguard_dns_filter" {
  name    = "AdGuard DNS filter"
  url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"
  enabled = true
}

resource "adguard_list_filter" "adaway_default" {
  name    = "AdAway Default Blocklist"
  url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt"
  enabled = true
}

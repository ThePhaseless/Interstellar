# =============================================================================
# AdGuard Home Configuration
# =============================================================================
# Manages AdGuard Home DNS settings via Terraform

# DNS Rewrites - Route *.nerine.dev to Traefik Tailscale IP
resource "adguard_rewrite" "nerine_dev_wildcard" {
  domain = "*.nerine.dev"
  answer = var.adguard_traefik_tailscale_ip
}

resource "adguard_rewrite" "nerine_dev" {
  domain = "nerine.dev"
  answer = var.adguard_traefik_tailscale_ip
}

# DNS Filter Lists
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

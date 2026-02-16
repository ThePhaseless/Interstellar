# =============================================================================
# Cloudflare DNS Configuration
# =============================================================================
# This file configures DNS records for the cluster services

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "cloudflare" {
  api_token = data.bitwarden-secrets_secret.cloudflare_api_token.value
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "cloudflare_zone" "main" {
  filter = {
    name = var.cluster_domain
  }
}

locals {
  oracle_public_ip = oci_core_instance.proxy.public_ip
  # Tailscale IP from Bitwarden (synced by Kubernetes CronJob)
  # Falls back to empty string if secret doesn't exist yet
  tailscale_traefik_ip = length(data.bitwarden-secrets_secret.tailscale_traefik_ip) > 0 ? data.bitwarden-secrets_secret.tailscale_traefik_ip[0].value : ""
}

# -----------------------------------------------------------------------------
# Public DNS Records (pointing to Oracle VPS)
# -----------------------------------------------------------------------------

# Wildcard record for all services (Oracle VPS - public fallback)
resource "cloudflare_dns_record" "wildcard" {
  zone_id = data.cloudflare_zone.main.id
  name    = "*"
  content = local.oracle_public_ip
  type    = "A"
  ttl     = 300
  proxied = false # DNS-only, no Cloudflare proxy (TLS at Traefik)
  comment = "Wildcard for all cluster services via Oracle HAProxy (public fallback)"
}

# Wildcard record for Tailscale direct access (preferred when reachable)
# Clients use "Happy Eyeballs" - will prefer Tailscale if connected, fallback to VPS otherwise
resource "cloudflare_dns_record" "wildcard_tailscale" {
  count   = local.tailscale_traefik_ip != "" ? 1 : 0
  zone_id = data.cloudflare_zone.main.id
  name    = "*"
  content = local.tailscale_traefik_ip
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Wildcard for Tailscale direct access (preferred for Tailscale users)"
}

# Root domain (Oracle VPS)
resource "cloudflare_dns_record" "root" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  content = local.oracle_public_ip
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Root domain via Oracle HAProxy"
}

# Root domain Tailscale (preferred when reachable)
resource "cloudflare_dns_record" "root_tailscale" {
  count   = local.tailscale_traefik_ip != "" ? 1 : 0
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  content = local.tailscale_traefik_ip
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Root domain via Tailscale direct (preferred)"
}

# -----------------------------------------------------------------------------
# CAA Record for Let's Encrypt
# -----------------------------------------------------------------------------
resource "cloudflare_dns_record" "caa" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  type    = "CAA"
  ttl     = 3600

  data = {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
  }

  comment = "Allow Let's Encrypt to issue certificates"
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  value       = data.cloudflare_zone.main.id
}

output "oracle_public_ip" {
  description = "Oracle VPS public IP for DNS records"
  value       = local.oracle_public_ip
}

# =============================================================================
# Cloudflare DNS Configuration
# =============================================================================
# This file configures DNS records for the cluster services

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "cloudflare" {
  api_token = data.bitwarden_secret.cloudflare_api_token.value
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "cloudflare_zone" "main" {
  filter = {
    name = var.cluster_domain
  }
}

# Oracle VPS public IP (fetched from OCI instance)
data "oci_core_instance" "oracle_vps" {
  instance_id = oci_core_instance.oracle_vps.id
}

locals {
  oracle_public_ip = data.oci_core_instance.oracle_vps.public_ip
}

# -----------------------------------------------------------------------------
# Public DNS Records (pointing to Oracle VPS)
# -----------------------------------------------------------------------------

# Wildcard record for all services
resource "cloudflare_dns_record" "wildcard" {
  zone_id = data.cloudflare_zone.main.id
  name    = "*"
  content = local.oracle_public_ip
  type    = "A"
  ttl     = 300
  proxied = false # DNS-only, no Cloudflare proxy (TLS at Traefik)
  comment = "Wildcard for all cluster services via Oracle HAProxy"
}

# Root domain
resource "cloudflare_dns_record" "root" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  content = local.oracle_public_ip
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Root domain via Oracle HAProxy"
}

# -----------------------------------------------------------------------------
# Specific Service Records (for clarity and documentation)
# -----------------------------------------------------------------------------

# Public services
resource "cloudflare_dns_record" "watch" {
  zone_id = data.cloudflare_zone.main.id
  name    = "watch"
  content = local.oracle_public_ip
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Jellyfin media streaming"
}

resource "cloudflare_dns_record" "add" {
  zone_id = data.cloudflare_zone.main.id
  name    = "add"
  content = local.oracle_public_ip
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Jellyseerr request management"
}

resource "cloudflare_dns_record" "files" {
  zone_id = data.cloudflare_zone.main.id
  name    = "files"
  content = local.oracle_public_ip
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Copyparty file server"
}

resource "cloudflare_dns_record" "photos" {
  zone_id = data.cloudflare_zone.main.id
  name    = "photos"
  content = local.oracle_public_ip
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Immich photo management"
}

resource "cloudflare_dns_record" "mcp" {
  zone_id = data.cloudflare_zone.main.id
  name    = "mcp"
  content = local.oracle_public_ip
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "MCPJungle MCP server registry"
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

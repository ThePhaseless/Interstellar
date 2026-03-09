provider "cloudflare" {
  api_token = bitwarden-secrets_secret.cloudflare_api_token.value != "" ? bitwarden-secrets_secret.cloudflare_api_token.value : "0000000000000000000000000000000000000000"
}

# Data Sources
data "cloudflare_zone" "main" {
  filter = {
    name = var.cluster_domain
  }
}

locals {
  oracle_public_ip = oci_core_instance.proxy.public_ip
}

# Public DNS Records (pointing to Oracle VPS)

# Wildcard record for all services (Oracle VPS)
resource "cloudflare_dns_record" "wildcard" {
  zone_id = data.cloudflare_zone.main.id
  name    = "*"
  content = local.oracle_public_ip
  type    = "A"
  ttl     = 300
  proxied = false # DNS-only, no Cloudflare proxy (TLS at Traefik)
  comment = "Wildcard for all cluster services via Oracle HAProxy"
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

# CAA Record for Let's Encrypt
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

# Outputs
output "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  value       = data.cloudflare_zone.main.id
  sensitive   = true
}

output "oracle_public_ip" {
  description = "Oracle VPS public IP for DNS records"
  value       = local.oracle_public_ip
  sensitive   = true
}

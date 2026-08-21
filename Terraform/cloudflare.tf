provider "cloudflare" {
  api_token = bitwarden-secrets_secret.cloudflare_api_token.value != "" ? bitwarden-secrets_secret.cloudflare_api_token.value : "0000000000000000000000000000000000000000"
}

# Data Sources
data "cloudflare_zone" "main" {
  filter = {
    name = var.cluster_domain
  }
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

# A Records for the home ingress (Traefik behind the residential connection).
# The residential IP is dynamic, so `content` is seeded here and then owned by
# the in-cluster cloudflare-ddns Deployment; Terraform must not fight it.
resource "cloudflare_dns_record" "root" {
  zone_id = data.cloudflare_zone.main.id
  name    = var.cluster_domain
  type    = "A"
  content = "83.5.155.50"
  ttl     = 60
  proxied = false

  comment = "Home Traefik ingress - value maintained by cloudflare-ddns"

  lifecycle {
    ignore_changes = [content]
  }
}

resource "cloudflare_dns_record" "wildcard" {
  zone_id = data.cloudflare_zone.main.id
  name    = "*.${var.cluster_domain}"
  type    = "A"
  content = "83.5.155.50"
  ttl     = 60
  proxied = false

  comment = "Home Traefik ingress - value maintained by cloudflare-ddns"

  lifecycle {
    ignore_changes = [content]
  }
}

# Outputs
output "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  value       = data.cloudflare_zone.main.id
  sensitive   = true
}


provider "cloudflare" {
  api_token = bitwarden-secrets_secret.cloudflare_api_token.value != "" ? bitwarden-secrets_secret.cloudflare_api_token.value : "0000000000000000000000000000000000000000"
}

data "cloudflare_zone" "main" {
  filter = {
    name = var.cluster_domain
  }
}

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

# `content` is only a seed: the residential IP is dynamic, so cloudflare-ddns owns it.
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

output "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  value       = data.cloudflare_zone.main.id
  sensitive   = true
}


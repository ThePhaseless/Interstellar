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

# Outputs
output "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  value       = data.cloudflare_zone.main.id
  sensitive   = true
}


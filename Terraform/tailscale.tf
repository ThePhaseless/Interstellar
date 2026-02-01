# =============================================================================
# Tailscale Configuration
# =============================================================================
# This file configures Tailscale ACL policy and auth keys

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "tailscale" {
  oauth_client_id     = data.bitwarden-secrets_secret.tailscale_oauth_client_id.value
  oauth_client_secret = data.bitwarden-secrets_secret.tailscale_oauth_secret.value
  tailnet             = data.bitwarden-secrets_secret.tailscale_tailnet.value
  scopes              = ["devices:core", "keys:auth_keys"]
}

# -----------------------------------------------------------------------------
# Tailscale Auth Key for Cluster Nodes
# -----------------------------------------------------------------------------
resource "tailscale_tailnet_key" "cluster" {
  reusable      = true
  preauthorized = true
  expiry        = 7776000 # 90 days in seconds
  tags          = ["tag:cluster", "tag:k8s-operator"]
  description   = "TalosOS cluster nodes auth key"
}

# Store the auth key in Bitwarden for External Secrets Operator
resource "bitwarden-secrets_secret" "tailscale_auth_key" {
  key        = "tailscale-auth-key"
  value      = tailscale_tailnet_key.cluster.key
  project_id = local.bitwarden_project_id
  note       = "Tailscale auth key for TalosOS cluster nodes. Managed by Terraform."
}

# -----------------------------------------------------------------------------
# Auto-generated Secrets
# -----------------------------------------------------------------------------

# Generate random cookie secret for OAuth2 Proxy
resource "random_password" "oauth_cookie_secret" {
  length  = 32
  special = false
}

# Store the cookie secret in Bitwarden
resource "bitwarden-secrets_secret" "oauth_cookie_secret" {
  key        = "google-oauth-cookie-secret"
  value      = random_password.oauth_cookie_secret.result
  project_id = local.bitwarden_project_id
  note       = "OAuth2 Proxy cookie secret. Managed by Terraform."
}

# -----------------------------------------------------------------------------
# Tailscale DNS Configuration
# -----------------------------------------------------------------------------
# MagicDNS is enabled for *.ts.net resolution.
# AdGuard DNS (adguard-shared) should be added manually in Tailscale Admin Console
# after the cluster is deployed:
#   1. Go to DNS settings in Tailscale Admin
#   2. Add adguard-shared's IP as a nameserver
#   3. Enable "Override local DNS"
# 
# Fallback DNS (1.1.1.1) is configured for when AdGuard is offline.
# -----------------------------------------------------------------------------
resource "tailscale_dns_configuration" "cluster" {
  magic_dns          = true
  override_local_dns = true

  nameservers {
    address = "100.100.100.100" # MagicDNS
  }

  nameservers {
    address = "1.1.1.1" # Cloudflare fallback
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "tailscale_cluster_auth_key" {
  description = "Tailscale auth key for cluster nodes (sensitive)"
  value       = tailscale_tailnet_key.cluster.key
  sensitive   = true
}

output "tailscale_auth_key_expiry" {
  description = "Tailscale auth key expiry date"
  value       = tailscale_tailnet_key.cluster.expires_at
}

# =============================================================================
# Tailscale Configuration
# =============================================================================
# This file configures Tailscale ACL policy and auth keys

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "tailscale" {
  api_key = data.bitwarden_secret.tailscale_api_key.value
  tailnet = data.bitwarden_secret.tailscale_tailnet.value
}

# -----------------------------------------------------------------------------
# Tailscale Auth Key for Cluster Nodes
# -----------------------------------------------------------------------------
resource "tailscale_tailnet_key" "cluster" {
  reusable      = true
  preauthorized = true
  expiry        = 7776000 # 90 days in seconds
  tags          = ["tag:cluster"]
  description   = "TalosOS cluster nodes auth key"
}

# Store the auth key in Bitwarden for External Secrets Operator
resource "bitwarden_secret" "tailscale_auth_key" {
  key        = "tailscale-auth-key"
  value      = tailscale_tailnet_key.cluster.key
  project_id = data.bitwarden_project.interstellar.id
  note       = "Tailscale auth key for TalosOS cluster nodes. Managed by Terraform."
}

# Reference the interstellar project
data "bitwarden_project" "interstellar" {
  id = data.bitwarden_secret.tailscale_api_key.project_id
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
resource "bitwarden_secret" "oauth_cookie_secret" {
  key        = "google-oauth-cookie-secret"
  value      = random_password.oauth_cookie_secret.result
  project_id = data.bitwarden_project.interstellar.id
  note       = "OAuth2 Proxy cookie secret. Managed by Terraform."
}

# -----------------------------------------------------------------------------
# Tailscale ACL Policy
# -----------------------------------------------------------------------------
# Note: The full ACL policy is maintained in Tailscale/policy.hujson
# and synced via GitHub Actions. This resource ensures Terraform
# can manage specific aspects if needed.

resource "tailscale_acl" "policy" {
  acl = file("${path.module}/../Tailscale/policy.hujson")

  # Only apply when the policy file changes
  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Tailscale DNS Configuration
# -----------------------------------------------------------------------------
resource "tailscale_dns_nameservers" "cluster" {
  nameservers = [
    "100.100.100.100", # MagicDNS
  ]
}

resource "tailscale_dns_preferences" "cluster" {
  magic_dns = true
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

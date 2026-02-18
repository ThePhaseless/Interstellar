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
  scopes              = ["devices:core", "auth_keys", "dns", "oauth_keys"]
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
resource "bitwarden-secrets_secret" "tailscale_auth_key" {
  key        = "tailscale-auth-key"
  value      = tailscale_tailnet_key.cluster.key
  project_id = local.bitwarden_project_id
  note       = "Tailscale auth key for TalosOS cluster nodes. Managed by Terraform."
}

# -----------------------------------------------------------------------------
# Managed OAuth Clients
# -----------------------------------------------------------------------------
# All OAuth clients are created by the provider (tag:ci) which owns all
# infrastructure tags via ACL tagOwners, so any tag can be assigned here.

locals {
  oauth_clients = {
    k8s_operator = {
      description = "K8s Tailscale operator"
      scopes      = ["auth_keys"]
      tags        = ["tag:k8s-operator"]
      bw_id_key   = "tailscale-k8s-oauth-client-id"
      bw_secret_key = "tailscale-k8s-oauth-secret"
    }
  }
}

resource "tailscale_oauth_client" "managed" {
  for_each    = local.oauth_clients
  description = each.value.description
  scopes      = each.value.scopes
  tags        = each.value.tags
}

resource "bitwarden-secrets_secret" "oauth_client_id" {
  for_each   = local.oauth_clients
  key        = each.value.bw_id_key
  value      = tailscale_oauth_client.managed[each.key].id
  project_id = local.bitwarden_project_id
  note       = "${each.value.description} OAuth client ID. Managed by Terraform."
}

resource "bitwarden-secrets_secret" "oauth_client_secret" {
  for_each   = local.oauth_clients
  key        = each.value.bw_secret_key
  value      = tailscale_oauth_client.managed[each.key].key
  project_id = local.bitwarden_project_id
  note       = "${each.value.description} OAuth client secret. Managed by Terraform."
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
# Tailscale Device Lookup
# -----------------------------------------------------------------------------
# Look up Tailscale devices created by the K8s Tailscale operator.
# On first apply (before K8s bootstrap), no devices exist — filters return
# empty lists, and dependent resources use count = 0. No chicken-egg errors.
# -----------------------------------------------------------------------------
data "tailscale_devices" "cluster" {}

locals {
  # Find Traefik device by hostname (exposed via tailscale.com/hostname annotation)
  traefik_devices = [
    for d in data.tailscale_devices.cluster.devices : d
    if d.hostname == "talos-traefik"
  ]
  tailscale_traefik_ip = length(local.traefik_devices) > 0 ? local.traefik_devices[0].addresses[0] : ""

  # Find AdGuard DNS device by hostname
  adguard_devices = [
    for d in data.tailscale_devices.cluster.devices : d
    if d.hostname == "adguard-shared"
  ]
  tailscale_adguard_ip = length(local.adguard_devices) > 0 ? local.adguard_devices[0].addresses[0] : ""
}

# -----------------------------------------------------------------------------
# Tailscale DNS Configuration
# -----------------------------------------------------------------------------
# MagicDNS for *.ts.net resolution.
# When AdGuard is deployed and reachable via Tailscale, it becomes the primary
# DNS server for all tailnet devices. 1.1.1.1 remains as fallback.
# -----------------------------------------------------------------------------
resource "tailscale_dns_configuration" "cluster" {
  magic_dns          = true
  override_local_dns = true

  # AdGuard as primary DNS (only when device exists on the tailnet)
  dynamic "nameservers" {
    for_each = local.tailscale_adguard_ip != "" ? [local.tailscale_adguard_ip] : []
    content {
      address = nameservers.value
    }
  }

  nameservers {
    address = "1.1.1.1"
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

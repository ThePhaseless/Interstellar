provider "tailscale" {
  oauth_client_id     = bitwarden-secrets_secret.tailscale_oauth_client_id.value != "" ? bitwarden-secrets_secret.tailscale_oauth_client_id.value : "unset"
  oauth_client_secret = bitwarden-secrets_secret.tailscale_oauth_secret.value != "" ? bitwarden-secrets_secret.tailscale_oauth_secret.value : "unset"
  tailnet             = local.tailscale_tailnet
  scopes              = ["devices:core", "auth_keys", "dns", "oauth_keys", "policy_file"]
}

# Tailscale ACL Policy
# Managed via GitOps. The provider's OAuth client (tag:ci) uses its policy_file
# scope to apply this configuration first, which enables it to own and manage
# other infrastructure tags.
resource "tailscale_acl" "main" {
  acl = file("${path.module}/../Tailscale/policy.hujson")
}

# Tailscale Auth Key for Cluster Nodes
resource "tailscale_tailnet_key" "cluster" {
  depends_on    = [tailscale_acl.main]
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
  project_id = local.bitwarden_generated_project_id
  note       = "Tailscale auth key for TalosOS cluster nodes. Managed by Terraform."
}

# Tailscale Auth Key for Oracle VPS Instances
resource "tailscale_tailnet_key" "oracle" {
  depends_on    = [tailscale_acl.main]
  reusable      = true
  preauthorized = true
  expiry        = 7776000 # 90 days in seconds
  tags          = ["tag:oracle"]
  description   = "Oracle VPS instances auth key"
}

resource "bitwarden-secrets_secret" "tailscale_oracle_auth_key" {
  key        = "tailscale-oracle-auth-key"
  value      = tailscale_tailnet_key.oracle.key
  project_id = local.bitwarden_generated_project_id
  note       = "Tailscale auth key for Oracle VPS instances. Managed by Terraform."
}

# Managed OAuth Clients
# All OAuth clients are created by the provider (tag:ci) which owns all
# infrastructure tags via ACL tagOwners, so any tag can be assigned here.

locals {
  oauth_clients = {
    ci = {
      description   = "GitHub Actions CI runner"
      scopes        = ["auth_keys"]
      tags          = ["tag:ci"]
      bw_id_key     = "tailscale-ci-oauth-client-id"
      bw_secret_key = "tailscale-ci-oauth-secret"
    }
    k8s_operator = {
      description   = "K8s Tailscale operator"
      scopes        = ["auth_keys"]
      tags          = ["tag:k8s-operator"]
      bw_id_key     = "tailscale-k8s-oauth-client-id"
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
  project_id = local.bitwarden_generated_project_id
  note       = "${each.value.description} OAuth client ID. Managed by Terraform."
}

resource "bitwarden-secrets_secret" "oauth_client_secret" {
  for_each   = local.oauth_clients
  key        = each.value.bw_secret_key
  value      = tailscale_oauth_client.managed[each.key].key
  project_id = local.bitwarden_generated_project_id
  note       = "${each.value.description} OAuth client secret. Managed by Terraform."
}

# Tailscale Device Lookup
# Look up Tailscale devices created by the K8s Tailscale operator.
# On first apply (before K8s bootstrap), no devices exist — filters return
# empty lists, and dependent resources use count = 0. No chicken-egg errors.
data "tailscale_devices" "cluster" {}

locals {
  # Find Traefik device by hostname (exposed via tailscale.com/hostname annotation)
  traefik_devices = [
    for d in data.tailscale_devices.cluster.devices : d
    if d.hostname == "traefik"
  ]
  tailscale_traefik_ip = length(local.traefik_devices) > 0 ? local.traefik_devices[0].addresses[0] : ""

  # Find AdGuard DNS device by hostname
  adguard_devices = [
    for d in data.tailscale_devices.cluster.devices : d
    if d.hostname == "adguard"
  ]
  tailscale_adguard_ip = length(local.adguard_devices) > 0 ? local.adguard_devices[0].addresses[0] : ""
}

# Tailscale DNS Configuration
# MagicDNS for *.ts.net resolution.
# When AdGuard is deployed and reachable via Tailscale, it becomes the primary
# DNS server for all tailnet devices. 1.1.1.1 remains as fallback.
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

# Outputs
output "tailscale_cluster_auth_key" {
  description = "Tailscale auth key for cluster nodes (sensitive)"
  value       = tailscale_tailnet_key.cluster.key
  sensitive   = true
}

output "tailscale_auth_key_expiry" {
  description = "Tailscale auth key expiry date"
  value       = tailscale_tailnet_key.cluster.expires_at
}

output "tailscale_oracle_auth_key" {
  description = "Tailscale auth key for Oracle VPS instances (sensitive)"
  value       = tailscale_tailnet_key.oracle.key
  sensitive   = true
}

output "tailscale_oracle_auth_key_expiry" {
  description = "Oracle Tailscale auth key expiry date"
  value       = tailscale_tailnet_key.oracle.expires_at
}

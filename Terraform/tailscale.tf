provider "tailscale" {
  oauth_client_id     = bitwarden-secrets_secret.tailscale_oauth_client_id.value != "" ? bitwarden-secrets_secret.tailscale_oauth_client_id.value : "unset"
  oauth_client_secret = bitwarden-secrets_secret.tailscale_oauth_secret.value != "" ? bitwarden-secrets_secret.tailscale_oauth_secret.value : "unset"
  tailnet             = local.tailscale_tailnet
  scopes              = ["devices:core", "auth_keys", "dns", "oauth_keys", "policy_file"]
}

# Applied first: its tagOwners are what let the provider (tag:ci) assign the tags below.
resource "tailscale_acl" "main" {
  acl = file("${path.module}/../Tailscale/policy.hujson")
}

resource "tailscale_tailnet_key" "cluster" {
  depends_on    = [tailscale_acl.main]
  reusable      = true
  preauthorized = true
  expiry        = 7776000 # 90 days in seconds
  tags          = ["tag:node"]
  description   = "TalosOS node auth key"
}

resource "bitwarden-secrets_secret" "tailscale_auth_key" {
  key        = "tailscale-auth-key"
  value      = tailscale_tailnet_key.cluster.key
  project_id = local.bitwarden_generated_project_id
  note       = "Tailscale auth key for TalosOS nodes. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}

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

# AdGuard only exists once the cluster has bootstrapped; until then the locals
# below fall back to 1.1.1.1 and skip split DNS.
data "tailscale_devices" "cluster" {}

locals {
  # Match by hostname only — the device name may carry a uniqueness suffix.
  adguard_devices = [
    for d in data.tailscale_devices.cluster.devices : d
    if d.hostname == "adguard"
  ]
  tailscale_adguard_ip = try(local.adguard_devices[0].addresses[0], "1.1.1.1")
  adguard_exists       = length(local.adguard_devices) >= 1

  infra_device_tags = ["tag:proxmox", "tag:node"]
  infra_devices = {
    for d in data.tailscale_devices.cluster.devices : d.name => d.id
    if length(setintersection(toset(d.tags), toset(local.infra_device_tags))) > 0
  }
}

# Headless nodes cannot answer a re-auth prompt, so an expired key would drop them off the tailnet.
resource "tailscale_device_key" "infra" {
  for_each = local.infra_devices

  device_id           = each.value
  key_expiry_disabled = true
}

# AdGuard is the only tailnet DNS resolver, so nerine.dev cannot resolve via
# public DNS while a client is connected through Tailscale.
resource "tailscale_dns_configuration" "cluster" {
  override_local_dns = true

  nameservers {
    address            = local.tailscale_adguard_ip
    use_with_exit_node = true
  }

  dynamic "split_dns" {
    for_each = local.adguard_exists ? [local.tailscale_adguard_ip] : []
    content {
      domain = var.cluster_domain

      nameservers {
        address            = split_dns.value
        use_with_exit_node = true
      }
    }
  }
}

output "tailscale_cluster_auth_key" {
  description = "Tailscale auth key for cluster nodes (sensitive)"
  value       = tailscale_tailnet_key.cluster.key
  sensitive   = true
}

output "tailscale_auth_key_expiry" {
  description = "Tailscale auth key expiry date"
  value       = tailscale_tailnet_key.cluster.expires_at
}


# =============================================================================
# Bitwarden Secrets Manager Configuration
# =============================================================================
# This file configures the Bitwarden Secrets Manager provider and resources.
# Critical provider credentials use data sources for stability, while others
# are bootstrapped as empty placeholders.

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "bitwarden-secrets" {
  api_url      = "https://api.bitwarden.com"
  identity_url = "https://identity.bitwarden.com"
}

# -----------------------------------------------------------------------------
# Project Lookup
# -----------------------------------------------------------------------------
data "bitwarden-secrets_projects" "all" {}

# Create a lookup map for existing secrets to avoid duplicate key errors
data "bitwarden-secrets_list_secrets" "all" {}

locals {
  secret_key_to_id = { for s in data.bitwarden-secrets_list_secrets.all.secrets : s.key => s.id }

  bitwarden_project_id = try(
    [for p in data.bitwarden-secrets_projects.all.projects : p.id if p.name == "interstellar"][0],
    data.bitwarden-secrets_projects.all.projects[0].id
  )
  bitwarden_generated_project_id = [for p in data.bitwarden-secrets_projects.all.projects : p.id if p.name == "interstellar-generated"][0]
}

# -----------------------------------------------------------------------------
# User-Managed Secrets (Terraform creates placeholders, user fills manually)
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "proxmox_user" {
  key        = "proxmox-user"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "Proxmox user for API authentication. Manually managed."
  lifecycle { ignore_changes = [value] }
}

resource "bitwarden-secrets_secret" "proxmox_token_id" {
  key        = "proxmox-token-id"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "Proxmox API token ID. Manually managed."
  lifecycle { ignore_changes = [value] }
}

# -----------------------------------------------------------------------------
# Individual Secret Data Sources (Critical provider credentials)
# -----------------------------------------------------------------------------
# These must exist in Bitwarden before Terraform can run successfully.

data "bitwarden-secrets_secret" "tailscale_oauth_client_id" {
  id = local.secret_key_to_id["tailscale-oauth-client-id"]
}

data "bitwarden-secrets_secret" "tailscale_oauth_secret" {
  id = local.secret_key_to_id["tailscale-oauth-secret"]
}

data "bitwarden-secrets_secret" "tailscale_tailnet" {
  id = local.secret_key_to_id["tailscale-tailnet"]
}

data "bitwarden-secrets_secret" "cloudflare_api_token" {
  id = local.secret_key_to_id["cloudflare-api-token"]
}

data "bitwarden-secrets_secret" "oci_config" {
  id = local.secret_key_to_id["oci-config"]
}

data "bitwarden-secrets_secret" "proxmox_api_token" {
  id = local.secret_key_to_id["proxmox-api-token"]
}

# -----------------------------------------------------------------------------
# Optional/Generated secrets
# -----------------------------------------------------------------------------

# Cluster API VIP (optional read path with var fallback)
data "bitwarden-secrets_secret" "cluster_vip" {
  count = contains(keys(local.secret_key_to_id), "cluster-vip") ? 1 : 0
  id    = local.secret_key_to_id["cluster-vip"]
}

resource "bitwarden-secrets_secret" "talosconfig" {
  key        = "talosconfig"
  value      = data.talos_client_configuration.cluster.talos_config
  note       = "Talosconfig for talosctl CLI access - managed by Terraform"
  project_id = local.bitwarden_generated_project_id
}

resource "bitwarden-secrets_secret" "oci_objectstorage_namespace" {
  key        = "oci-namespace"
  value      = data.oci_objectstorage_namespace.ns.namespace
  note       = "OCI Object Storage namespace for Terraform state bucket - managed by Terraform"
  project_id = local.bitwarden_generated_project_id
}

resource "bitwarden-secrets_secret" "cluster_vip" {
  key        = "cluster-vip"
  value      = var.cluster_vip
  note       = "Talos/Kubernetes control-plane virtual IP - managed by Terraform"
  project_id = local.bitwarden_generated_project_id
}

# -----------------------------------------------------------------------------
# Computed values from secrets
# -----------------------------------------------------------------------------
locals {
  tailscale_tailnet = data.bitwarden-secrets_secret.tailscale_tailnet.value

  oci_tenancy_ocid = regex("tenancy=([^\n]+)", data.bitwarden-secrets_secret.oci_config.value)[0]
  oci_user_ocid    = regex("user=([^\n]+)", data.bitwarden-secrets_secret.oci_config.value)[0]
  oci_region       = regex("region=([^\n]+)", data.bitwarden-secrets_secret.oci_config.value)[0]

  # Resolve cluster VIP from Bitwarden when available, otherwise use Terraform variable.
  cluster_vip = length(data.bitwarden-secrets_secret.cluster_vip) > 0 ? data.bitwarden-secrets_secret.cluster_vip[0].value : var.cluster_vip
}

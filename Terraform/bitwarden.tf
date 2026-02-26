# =============================================================================
# Bitwarden Secrets Manager Configuration
# =============================================================================
# This file configures the Bitwarden Secrets Manager provider and data sources
# for all infrastructure secrets.

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
# The access token is provided via environment variable BWS_ACCESS_TOKEN
# which is set from GitHub Secrets or local .env file

provider "bitwarden-secrets" {
  # Access token is read from BW_ACCESS_TOKEN environment variable
  # Organization ID is read from BW_ORGANIZATION_ID environment variable
  api_url      = "https://api.bitwarden.com"
  identity_url = "https://identity.bitwarden.com"
}

# -----------------------------------------------------------------------------
# Data Sources - Fetch all secrets and create lookup map
# -----------------------------------------------------------------------------

# Get list of all secrets (returns id and key only)
data "bitwarden-secrets_list_secrets" "all" {}

# Get list of all projects to find the interstellar project
data "bitwarden-secrets_projects" "all" {}

# Create a map from key to id for easy lookup
locals {
  secret_key_to_id = { for s in data.bitwarden-secrets_list_secrets.all.secrets : s.key => s.id }
  # Get project ID for admin-managed secrets (manually filled by admin)
  bitwarden_project_id = try(
    [for p in data.bitwarden-secrets_projects.all.projects : p.id if p.name == "interstellar"][0],
    data.bitwarden-secrets_projects.all.projects[0].id
  )
  # Get project ID for auto-generated secrets (managed by Terraform/apps)
  bitwarden_generated_project_id = [for p in data.bitwarden-secrets_projects.all.projects : p.id if p.name == "interstellar-generated"][0]
  # Tailscale tailnet name for use throughout the configuration
  tailscale_tailnet = data.bitwarden-secrets_secret.tailscale_tailnet.value
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
# User-Managed Secrets (Terraform creates placeholders, user fills manually)
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "proxmox_user" {
  key        = "proxmox-user"
  value      = "root@pam"
  project_id = local.bitwarden_project_id
  note       = "Proxmox user for API authentication. Manually managed."
  lifecycle { ignore_changes = [value] }
}

resource "bitwarden-secrets_secret" "proxmox_token_id" {
  key        = "proxmox-token-id"
  value      = "terraform"
  project_id = local.bitwarden_project_id
  note       = "Proxmox API token ID. Manually managed."
  lifecycle { ignore_changes = [value] }
}

# -----------------------------------------------------------------------------
# Optional secrets (read-only lookup)
# -----------------------------------------------------------------------------

# Cluster API VIP (optional read path with var fallback)
data "bitwarden-secrets_secret" "cluster_vip" {
  count = contains(keys(local.secret_key_to_id), "cluster-vip") ? 1 : 0
  id    = local.secret_key_to_id["cluster-vip"]
}

# -----------------------------------------------------------------------------
# Managed Secrets (uploaded to Bitwarden)
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "talosconfig" {
  key        = "talosconfig"
  value      = data.talos_client_configuration.cluster.talos_config
  note       = "Talosconfig for talosctl CLI access - managed by Terraform"
  project_id = local.bitwarden_generated_project_id
}

# OCI Object Storage namespace (used for backend migrations)
resource "bitwarden-secrets_secret" "oci_objectstorage_namespace" {
  key        = "oci-namespace"
  value      = data.oci_objectstorage_namespace.ns.namespace
  note       = "OCI Object Storage namespace for Terraform state bucket - managed by Terraform"
  project_id = local.bitwarden_generated_project_id
}

# Cluster control-plane VIP for consistent API endpoint management
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
  # Extract OCI tenancy OCID from oci-config (format: tenancy=ocid1.tenancy.oc1...)
  oci_tenancy_ocid = regex("tenancy=([^\n]+)", data.bitwarden-secrets_secret.oci_config.value)[0]

  # Extract OCI user OCID from oci-config (format: user=ocid1.user.oc1...)
  oci_user_ocid = regex("user=([^\n]+)", data.bitwarden-secrets_secret.oci_config.value)[0]

  # Extract OCI region from oci-config (format: region=us-ashburn-1)
  oci_region = regex("region=([^\n]+)", data.bitwarden-secrets_secret.oci_config.value)[0]

  # Resolve cluster VIP from Bitwarden when available, otherwise use Terraform variable.
  cluster_vip = length(data.bitwarden-secrets_secret.cluster_vip) > 0 ? data.bitwarden-secrets_secret.cluster_vip[0].value : var.cluster_vip
}

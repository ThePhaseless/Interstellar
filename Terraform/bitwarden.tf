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
  # Get project ID for creating new secrets (use the first project, or find "interstellar" if exists)
  bitwarden_project_id = try(
    [for p in data.bitwarden-secrets_projects.all.projects : p.id if p.name == "interstellar"][0],
    data.bitwarden-secrets_projects.all.projects[0].id
  )
  # Tailscale tailnet name for use throughout the configuration
  tailscale_tailnet = data.bitwarden-secrets_secret.tailscale_tailnet.value
}

# -----------------------------------------------------------------------------
# Individual Secret Data Sources (fetched by ID using the lookup)
# -----------------------------------------------------------------------------

# Tailscale OAuth credentials
data "bitwarden-secrets_secret" "tailscale_oauth_client_id" {
  id = local.secret_key_to_id["tailscale-oauth-client-id"]
}

data "bitwarden-secrets_secret" "tailscale_oauth_secret" {
  id = local.secret_key_to_id["tailscale-oauth-secret"]
}

data "bitwarden-secrets_secret" "tailscale_tailnet" {
  id = local.secret_key_to_id["tailscale-tailnet"]
}

# Cloudflare API token
data "bitwarden-secrets_secret" "cloudflare_api_token" {
  id = local.secret_key_to_id["cloudflare-api-token"]
}

# OCI Config (contains tenancy OCID)
data "bitwarden-secrets_secret" "oci_config" {
  id = local.secret_key_to_id["oci-config"]
}

# -----------------------------------------------------------------------------
# Optional secrets (may not exist yet)
# -----------------------------------------------------------------------------

# Discord webhook for alerts
data "bitwarden-secrets_secret" "discord_webhook_url" {
  count = contains(keys(local.secret_key_to_id), "discord-webhook-url") ? 1 : 0
  id    = local.secret_key_to_id["discord-webhook-url"]
}

# CrowdSec API key
data "bitwarden-secrets_secret" "crowdsec_api_key" {
  count = contains(keys(local.secret_key_to_id), "crowdsec-api-key") ? 1 : 0
  id    = local.secret_key_to_id["crowdsec-api-key"]
}

# Copyparty access groups (used for file write permissions)
data "bitwarden-secrets_secret" "copyparty_admins" {
  count = contains(keys(local.secret_key_to_id), "copyparty-admins") ? 1 : 0
  id    = local.secret_key_to_id["copyparty-admins"]
}

data "bitwarden-secrets_secret" "copyparty_writers" {
  count = contains(keys(local.secret_key_to_id), "copyparty-writers") ? 1 : 0
  id    = local.secret_key_to_id["copyparty-writers"]
}

# Cluster API VIP (optional read path with var fallback)
data "bitwarden-secrets_secret" "cluster_vip" {
  count = contains(keys(local.secret_key_to_id), "cluster-vip") ? 1 : 0
  id    = local.secret_key_to_id["cluster-vip"]
}

# -----------------------------------------------------------------------------
# Managed Secrets (uploaded to Bitwarden)
# -----------------------------------------------------------------------------

# Talosconfig for talosctl CLI access
resource "bitwarden-secrets_secret" "talosconfig" {
  key        = "talosconfig"
  value      = data.talos_client_configuration.cluster.talos_config
  note       = "Talosconfig for talosctl CLI access - managed by Terraform"
  project_id = local.bitwarden_project_id
}

# OCI Object Storage namespace (used for backend migrations)
resource "bitwarden-secrets_secret" "oci_objectstorage_namespace" {
  key        = "oci-namespace"
  value      = data.oci_objectstorage_namespace.ns.namespace
  note       = "OCI Object Storage namespace for Terraform state bucket - managed by Terraform"
  project_id = local.bitwarden_project_id
}

# Cluster control-plane VIP for consistent API endpoint management
resource "bitwarden-secrets_secret" "cluster_vip" {
  key        = "cluster-vip"
  value      = var.cluster_vip
  note       = "Talos/Kubernetes control-plane virtual IP - managed by Terraform"
  project_id = local.bitwarden_project_id
}

# -----------------------------------------------------------------------------
# Computed values from secrets
# -----------------------------------------------------------------------------
locals {
  # Extract OCI tenancy OCID from oci-config (format: tenancy=ocid1.tenancy.oc1...)
  oci_tenancy_ocid = regex("tenancy=([^\n]+)", data.bitwarden-secrets_secret.oci_config.value)[0]

  # Resolve cluster VIP from Bitwarden when available, otherwise use Terraform variable.
  cluster_vip = length(data.bitwarden-secrets_secret.cluster_vip) > 0 ? data.bitwarden-secrets_secret.cluster_vip[0].value : var.cluster_vip
}

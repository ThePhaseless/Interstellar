# =============================================================================
# GitHub Repository Variables for Bitwarden Secret IDs
# =============================================================================
# This file manages GitHub repository variables that store Bitwarden Secret IDs.
# Direct resource references ensure IDs are always current after Terraform runs.

provider "github" {
  owner = split("/", var.github_repository)[0]
}

locals {
  github_repo_name = split("/", var.github_repository)[1]

  # Map of GitHub variable names to Bitwarden Secret IDs
  # Using direct resource references for all managed secrets
  bws_id_map = {
    "OCI_CONFIG"                = bitwarden-secrets_secret.oci_config.id
    "OCI_PRIVATE_KEY"           = bitwarden-secrets_secret.oci_private_key.id
    "OCI_NAMESPACE"             = bitwarden-secrets_secret.oci_objectstorage_namespace.id
    "TF_STATE_BUCKET"           = bitwarden-secrets_secret.tf_state_bucket.id
    "TS_OAUTH_CLIENT_ID"        = bitwarden-secrets_secret.tailscale_oauth_client_id.id
    "TS_OAUTH_SECRET"           = bitwarden-secrets_secret.tailscale_oauth_secret.id
    "TS_CI_OAUTH_CLIENT_ID"     = bitwarden-secrets_secret.oauth_client_id["ci"].id
    "TS_CI_OAUTH_SECRET"        = bitwarden-secrets_secret.oauth_client_secret["ci"].id
    "PROXMOX_API_TOKEN"         = bitwarden-secrets_secret.proxmox_api_token.id
    "HCLOUD_TOKEN"              = bitwarden-secrets_secret.hcloud_token.id
    "ORACLE_SSH_PRIVATE_KEY"    = bitwarden-secrets_secret.oracle_ssh_private_key.id
    "TAILSCALE_ORACLE_AUTH_KEY" = bitwarden-secrets_secret.tailscale_oracle_auth_key.id
  }
}

resource "github_actions_variable" "bws_id" {
  for_each      = var.enable_github_mgmt ? local.bws_id_map : {}
  repository    = local.github_repo_name
  variable_name = "BWS_ID_${each.key}"
  value         = each.value
}

resource "github_actions_variable" "proxmox_user" {
  count         = var.enable_github_mgmt ? 1 : 0
  repository    = local.github_repo_name
  variable_name = "PROXMOX_USER"
  value         = bitwarden-secrets_secret.proxmox_user.value
}

resource "github_actions_variable" "proxmox_token_id" {
  count         = var.enable_github_mgmt ? 1 : 0
  repository    = local.github_repo_name
  variable_name = "PROXMOX_TOKEN_ID"
  value         = bitwarden-secrets_secret.proxmox_token_id.value
}

resource "github_actions_secret" "proxmox_token" {
  count           = var.enable_github_mgmt ? 1 : 0
  repository      = local.github_repo_name
  secret_name     = "PROXMOX_VE_API_TOKEN"
  plaintext_value = "${bitwarden-secrets_secret.proxmox_user.value}!${bitwarden-secrets_secret.proxmox_token_id.value}=${bitwarden-secrets_secret.proxmox_api_token.value}"
}

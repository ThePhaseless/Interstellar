# =============================================================================
# GitHub Repository Variables for Bitwarden Secret IDs
# =============================================================================
# This file manages GitHub repository variables that store Bitwarden Secret IDs.
# This allows GitHub Actions to use sm-action with dynamic IDs without hardcoding.

provider "github" {
  owner = split("/", var.github_repository)[0]
}

resource "github_actions_variable" "bws_id" {
  for_each = {
    "OCI_CONFIG"         = "oci-config"
    "OCI_PRIVATE_KEY"    = "oci-private-key"
    "OCI_NAMESPACE"      = "oci-namespace"
    "TS_OAUTH_CLIENT_ID" = "tailscale-oauth-client-id"
    "TS_OAUTH_SECRET"    = "tailscale-oauth-secret"
    "TS_CI_AUTH_KEY"     = "tailscale-ci-auth-key"
    "TF_STATE_BUCKET"    = "tf-state-bucket"
    "PROXMOX_API_TOKEN"  = "proxmox-api-token"
  }

  repository    = split("/", var.github_repository)[1]
  variable_name = "BWS_ID_${each.key}"
  value         = try(local.secret_key_to_id[each.value], "placeholder")
}

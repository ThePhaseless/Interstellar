# =============================================================================
# Kubernetes Bootstrap Resources
# =============================================================================
# Resources that must be created directly via Terraform because they're needed
# before ESO (External Secrets Operator) can function.
# This solves the chicken-and-egg problem: ESO needs a Bitwarden access token
# to fetch secrets, but the token itself is a secret.

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "kubernetes" {
  host                   = talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.host
  client_certificate     = base64decode(talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.ca_certificate)
}

# -----------------------------------------------------------------------------
# Bitwarden Access Token Secret
# -----------------------------------------------------------------------------
# This secret is consumed by the bitwarden-sdk-server (ESO backend) to
# authenticate with Bitwarden Secrets Manager. Without it, no ExternalSecrets
# can be synced.
#
# The BWS_ACCESS_TOKEN env var is already available in the Terraform environment
# (sourced from .env locally, or GitHub Secrets in CI).
resource "kubernetes_secret_v1" "bitwarden_access_token" {
  metadata {
    name      = "bitwarden-access-token"
    namespace = "external-secrets"
  }

  data = {
    token = var.bws_access_token
  }

  lifecycle {
    # Don't destroy the secret if Terraform is run without the cluster
    prevent_destroy = true
  }
}

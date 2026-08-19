provider "kubernetes" {
  host                   = "https://${coalesce(var.kubernetes_api_host, var.cluster_vip)}:6443"
  client_certificate     = base64decode(talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.ca_certificate)
}

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
  }

  lifecycle {
    # Argo CD mutates namespace labels/annotations; don't churn Terraform plans.
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels,
    ]
  }
}

resource "kubernetes_secret_v1" "bitwarden_access_token_kubernetes" {
  metadata {
    name      = "bitwarden-access-token-kubernetes"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }

  data = {
    token = bitwarden-secrets_secret.bitwarden_access_token_kubernetes.value
  }
}

provider "sonarr" {
  url     = var.sonarr_provider_url
  api_key = data.bitwarden-secrets_secret.sonarr_api_key.value
}

provider "radarr" {
  url     = var.radarr_provider_url
  api_key = data.bitwarden-secrets_secret.radarr_api_key.value
}

provider "prowlarr" {
  url     = var.prowlarr_provider_url
  api_key = data.bitwarden-secrets_secret.prowlarr_api_key.value
}

provider "adguard" {
  host     = var.adguard_provider_url
  scheme   = "http"
  username = "admin"
  password = "admin123"
}

provider "authentik" {
  url   = var.authentik_provider_url
  token = data.bitwarden-secrets_secret.authentik_bootstrap_token.value
}

provider "kubernetes" {}

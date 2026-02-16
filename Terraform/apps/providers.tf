provider "sonarr" {
  url     = var.sonarr_url
  api_key = data.bitwarden-secrets_secret.sonarr_api_key.value
}

provider "radarr" {
  url     = var.radarr_url
  api_key = data.bitwarden-secrets_secret.radarr_api_key.value
}

provider "prowlarr" {
  url     = var.prowlarr_url
  api_key = data.bitwarden-secrets_secret.prowlarr_api_key.value
}

provider "grafana" {
  url  = var.grafana_url
  auth = data.bitwarden-secrets_secret.grafana_auth.value
}

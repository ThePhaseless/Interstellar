locals {
  sonarr_provider_url   = var.sonarr_provider_url
  radarr_provider_url   = var.radarr_provider_url
  prowlarr_provider_url = var.prowlarr_provider_url
  adguard_provider_url  = var.adguard_provider_url
}

provider "sonarr" {
  url     = local.sonarr_provider_url
  api_key = data.bitwarden-secrets_secret.sonarr_api_key.value
}

provider "radarr" {
  url     = local.radarr_provider_url
  api_key = data.bitwarden-secrets_secret.radarr_api_key.value
}

provider "prowlarr" {
  url     = local.prowlarr_provider_url
  api_key = data.bitwarden-secrets_secret.prowlarr_api_key.value
}

provider "adguard" {
  host     = local.adguard_provider_url
  username = "admin"
  password = "admin"
}


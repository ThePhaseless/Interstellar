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

# AdGuard has no users configured, so it accepts these unread — the provider
# just refuses to start without a non-empty username and password.
provider "adguard" {
  host     = var.adguard_provider_url
  scheme   = "http"
  username = "admin"
  password = data.bitwarden-secrets_secret.adguard_admin_password.value
}

provider "authentik" {
  url   = var.authentik_provider_url
  token = data.bitwarden-secrets_secret.authentik_bootstrap_token.value
}

provider "jellyfin" {
  endpoint = var.jellyfin_provider_url
  api_key  = data.bitwarden-secrets_secret.jellyfin_api_key.value
}

provider "kubernetes" {}

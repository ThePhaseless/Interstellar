locals {
  prowlarr_sonarr_sync_categories = [5000, 8000]
  prowlarr_radarr_sync_categories = [2000, 8000]
}

resource "sonarr_download_client" "qbittorrent" {
  enable          = true
  priority        = 1
  name            = "qBittorrent"
  implementation  = "QBittorrent"
  protocol        = "torrent"
  config_contract = "QBittorrentSettings"
  host            = var.qbittorrent_host
  port            = var.qbittorrent_port
  # No credentials — qBittorrent auth is disabled; Traefik middleware handles web UI auth
  tv_category = var.sonarr_tv_category

  remove_completed_downloads = true
  remove_failed_downloads    = true
}

resource "radarr_download_client" "qbittorrent" {
  enable          = true
  priority        = 1
  name            = "qBittorrent"
  implementation  = "QBittorrent"
  protocol        = "torrent"
  config_contract = "QBittorrentSettings"
  host            = var.qbittorrent_host
  port            = var.qbittorrent_port
  # No credentials — qBittorrent auth is disabled; Traefik middleware handles web UI auth
  movie_category = var.radarr_movie_category

  remove_completed_downloads = true
  remove_failed_downloads    = true
}

resource "prowlarr_indexer_proxy_flaresolverr" "byparr" {
  name            = "Byparr"
  host            = var.byparr_url
  request_timeout = 60
}

resource "prowlarr_application" "sonarr" {
  name            = "Sonarr"
  sync_level      = "fullSync"
  implementation  = "Sonarr"
  config_contract = "SonarrSettings"
  base_url        = var.sonarr_url
  prowlarr_url    = var.prowlarr_url
  api_key         = data.bitwarden-secrets_secret.sonarr_api_key.value
  sync_categories = local.prowlarr_sonarr_sync_categories
}

resource "prowlarr_application" "radarr" {
  name            = "Radarr"
  sync_level      = "fullSync"
  implementation  = "Radarr"
  config_contract = "RadarrSettings"
  base_url        = var.radarr_url
  prowlarr_url    = var.prowlarr_url
  api_key         = data.bitwarden-secrets_secret.radarr_api_key.value
  sync_categories = local.prowlarr_radarr_sync_categories
}

resource "sonarr_notification_discord" "discord" {
  name         = "Discord"
  web_hook_url = data.bitwarden-secrets_secret.discord_webhook_url.value

  on_import_complete = true
  on_series_add      = true
  on_series_delete   = true
  on_health_issue    = true
  on_health_restored = true
}

resource "radarr_notification_discord" "discord" {
  name         = "Discord"
  web_hook_url = data.bitwarden-secrets_secret.discord_webhook_url.value

  on_download        = true
  on_movie_delete    = true
  on_health_issue    = true
  on_health_restored = true
}

resource "prowlarr_notification_discord" "discord" {
  name         = "Discord"
  web_hook_url = data.bitwarden-secrets_secret.discord_webhook_url.value

  on_health_issue    = true
  on_health_restored = true
}

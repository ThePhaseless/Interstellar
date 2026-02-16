locals {
  prowlarr_sonarr_sync_categories = [5000, 5010, 5020, 5030, 5040, 5045, 5050]
  prowlarr_radarr_sync_categories = [2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060]
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
  use_ssl         = false
  url_base        = ""
  username        = data.bitwarden-secrets_secret.qbittorrent_username.value
  password        = data.bitwarden-secrets_secret.qbittorrent_password.value
  tv_category     = var.sonarr_tv_category

  remove_completed_downloads = true
  remove_failed_downloads    = true
  sequential_order           = false
  first_and_last             = false
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
  use_ssl         = false
  url_base        = ""
  username        = data.bitwarden-secrets_secret.qbittorrent_username.value
  password        = data.bitwarden-secrets_secret.qbittorrent_password.value
  movie_category  = var.radarr_movie_category

  remove_completed_downloads = true
  remove_failed_downloads    = true
  sequential_order           = false
  first_and_last             = false
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

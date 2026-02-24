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
  username        = data.bitwarden-secrets_secret.qbittorrent_username.value
  password        = data.bitwarden-secrets_secret.qbittorrent_password.value
  tv_category     = var.sonarr_tv_category

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
  username        = data.bitwarden-secrets_secret.qbittorrent_username.value
  password        = data.bitwarden-secrets_secret.qbittorrent_password.value
  movie_category  = var.radarr_movie_category

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

# =============================================================================
# Email Notifications (critical alerts only)
# =============================================================================
# Email is reserved for critical events: health issues, manual intervention.
# All *arr apps send through the cluster Postfix relay (no auth, no TLS).

resource "sonarr_notification_email" "email" {
  name = "Email (Critical)"

  server         = "postfix.utilities.svc.cluster.local"
  port           = 587
  from           = "noreply@nerine.dev"
  to             = [data.bitwarden-secrets_secret.owner_email.value]
  use_encryption = 2 # Never — cluster-internal plain SMTP

  on_health_issue                    = true
  on_health_restored                 = true
  on_manual_interaction_required     = true
  include_health_warnings            = true
  on_grab                            = false
  on_download                        = false
  on_upgrade                         = false
  on_import_complete                 = false
  on_application_update              = false
  on_series_add                      = false
  on_series_delete                   = false
  on_episode_file_delete             = false
  on_episode_file_delete_for_upgrade = false
}

resource "radarr_notification_email" "email" {
  name = "Email (Critical)"

  server         = "postfix.utilities.svc.cluster.local"
  port           = 587
  from           = "noreply@nerine.dev"
  to             = [data.bitwarden-secrets_secret.owner_email.value]
  use_encryption = 2 # Never — cluster-internal plain SMTP

  on_health_issue                  = true
  on_health_restored               = true
  on_manual_interaction_required   = true
  include_health_warnings          = true
  on_grab                          = false
  on_download                      = false
  on_upgrade                       = false
  on_application_update            = false
  on_movie_added                   = false
  on_movie_delete                  = false
  on_movie_file_delete             = false
  on_movie_file_delete_for_upgrade = false
}

resource "prowlarr_notification_email" "email" {
  name = "Email (Critical)"

  server         = "postfix.utilities.svc.cluster.local"
  port           = 587
  from           = "noreply@nerine.dev"
  to             = [data.bitwarden-secrets_secret.owner_email.value]
  use_encryption = 2 # Never — cluster-internal plain SMTP

  on_health_issue         = true
  on_health_restored      = true
  include_health_warnings = true
  on_application_update   = false
  on_grab                 = false
}

# =============================================================================
# Discord Notifications (standard events)
# =============================================================================
# Discord webhook for routine notifications: grabs, downloads, upgrades, etc.

resource "sonarr_notification_discord" "discord" {
  name         = "Discord"
  web_hook_url = data.bitwarden-secrets_secret.discord_webhook_url.value

  on_grab                            = true
  on_download                        = true
  on_upgrade                         = true
  on_import_complete                 = true
  on_series_add                      = true
  on_series_delete                   = false
  on_episode_file_delete             = false
  on_episode_file_delete_for_upgrade = false
  on_rename                          = false
  on_application_update              = true
  on_health_issue                    = false
  on_health_restored                 = false
  on_manual_interaction_required     = false
  include_health_warnings            = false
}

resource "radarr_notification_discord" "discord" {
  name         = "Discord"
  web_hook_url = data.bitwarden-secrets_secret.discord_webhook_url.value

  on_grab                          = true
  on_download                      = true
  on_upgrade                       = true
  on_movie_delete                  = false
  on_movie_file_delete             = false
  on_movie_file_delete_for_upgrade = false
  on_rename                        = false
  on_application_update            = true
  on_health_issue                  = false
  on_health_restored               = false
  on_manual_interaction_required   = false
  include_health_warnings          = false
}

resource "prowlarr_notification_discord" "discord" {
  name         = "Discord"
  web_hook_url = data.bitwarden-secrets_secret.discord_webhook_url.value

  on_grab                 = true
  on_application_update   = true
  on_health_issue         = false
  on_health_restored      = false
  include_health_warnings = false
}

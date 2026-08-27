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

# Prowlarr owns rejectBlocklistedTorrentHashesWhileGrabbing on the *arr side:
# fullSync rebuilds every synced indexer from Prowlarr's definition, so setting
# it in Sonarr/Radarr is undone on the next sync. devopsarr/prowlarr 3.2.1 has
# no attribute for it. A prowlarr_application update resets fields the provider
# does not know back to their defaults, hence triggering on its whole config.
resource "terraform_data" "prowlarr_reject_blocklisted_hashes" {
  for_each = {
    sonarr = prowlarr_application.sonarr
    radarr = prowlarr_application.radarr
  }

  triggers_replace = [
    each.value.id,
    each.value.sync_level,
    join(",", sort([for category in each.value.sync_categories : tostring(category)])),
  ]

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]

    environment = {
      PROWLARR_URL = var.prowlarr_provider_url
      PROWLARR_KEY = data.bitwarden-secrets_secret.prowlarr_api_key.value
      APP_ID       = tostring(each.value.id)
    }

    command = <<-EOT
      set -euo pipefail

      application=$(curl -sf -H "X-Api-Key: $PROWLARR_KEY" \
        "$PROWLARR_URL/api/v1/applications/$APP_ID")

      printf '%s' "$application" \
        | jq '.fields |= map(
            if .name == "syncRejectBlocklistedTorrentHashesWhileGrabbing"
            then .value = true else . end)' \
        | curl -sf -X PUT --data-binary @- \
            -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" \
            "$PROWLARR_URL/api/v1/applications/$APP_ID" >/dev/null

      curl -sf -X POST -d '{"name":"ApplicationIndexerSync"}' \
        -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" \
        "$PROWLARR_URL/api/v1/command" >/dev/null
    EOT
  }
}

# doNotPrefer takes proper/repack out of the revision gate that vetoes any
# same-quality upgrade, and lets the Repack/Proper custom formats (5/6/7, from
# the TRaSH profiles Recyclarr syncs) rank it as part of the total score
# instead. Every attribute below is required by the provider, so the rest
# mirror the live config rather than expressing an intent.
resource "radarr_media_management" "movies" {
  download_propers_and_repacks = "doNotPrefer"

  auto_rename_folders                         = false
  auto_unmonitor_previously_downloaded_movies = false
  chmod_folder                                = "755"
  chown_group                                 = ""
  copy_using_hardlinks                        = true
  create_empty_movie_folders                  = false
  delete_empty_folders                        = false
  enable_media_info                           = true
  extra_file_extensions                       = "srt"
  file_date                                   = "none"
  import_extra_files                          = false
  minimum_free_space_when_importing           = 100
  paths_default_static                        = false
  recycle_bin                                 = ""
  recycle_bin_cleanup_days                    = 7
  rescan_after_refresh                        = "always"
  set_permissions_linux                       = false
  skip_free_space_check_when_importing        = false
}

resource "sonarr_media_management" "series" {
  download_propers_repacks = "doNotPrefer"

  chmod_folder                = "755"
  chown_group                 = ""
  create_empty_folders        = false
  delete_empty_folders        = false
  enable_media_info           = true
  episode_title_required      = "always"
  extra_file_extensions       = "srt"
  file_date                   = "none"
  hardlinks_copy              = true
  import_extra_files          = false
  minimum_free_space          = 100
  recycle_bin_days            = 7
  recycle_bin_path            = ""
  rescan_after_refresh        = "always"
  set_permissions             = false
  skip_free_space_check       = false
  unmonitor_previous_episodes = false
}

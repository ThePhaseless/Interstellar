# Jellyfin state that used to be enforced by the Kubernetes setup sidecar.
# Keep library management to identity and paths for now: importing the live
# library_options_json worked, but replaying the full payload back to Jellyfin
# 10.11.8 returned 400s on this server.

locals {
  jellyfin_sso_plugin_repository_url = "https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json"
}

resource "jellyfin_library" "movies" {
  collection_type = "movies"
  name            = "Movies"
  paths           = ["/media/Movies"]
}

resource "jellyfin_library" "collections" {
  collection_type = "boxsets"
  name            = "Collections"
  paths           = ["/config/data/collections"]
}

resource "jellyfin_library" "tv_shows" {
  collection_type = "tvshows"
  name            = "TV Shows"
  paths           = ["/media/TVShows"]
}

resource "jellyfin_plugin_repository" "sso_auth" {
  enabled = true
  name    = "SSO-Auth"
  url     = local.jellyfin_sso_plugin_repository_url
}

# jellyfin_plugin "sso_auth" and jellyfin_plugin_configuration are NOT managed
# by Terraform: the thephaseless/jellyfin provider v0.1.0 Read function can't
# find installed plugins, so import fails silently and create hits 404 because
# the plugin is already there. The plugin and its configuration are restored
# from Borg backups and applied manually. See AGENTS.md Key Gotchas.


resource "jellyfin_branding_configuration" "this" {
  configuration_json = jsonencode({
    LoginDisclaimer     = file("${path.module}/files/jellyfin/branding/disclaimer.html")
    CustomCss           = file("${path.module}/files/jellyfin/branding/custom.css")
    SplashscreenEnabled = false
  })
}

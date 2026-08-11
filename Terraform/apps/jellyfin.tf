# Jellyfin state that used to be enforced by the Kubernetes setup sidecar.
# Keep library management to identity and paths for now: importing the live
# library_options_json worked, but replaying the full payload back to Jellyfin
# 10.11.8 returned 400s on this server.

locals {
  jellyfin_security_plugin_repository_url = "https://raw.githubusercontent.com/ZL154/JellyfinSecurity/main/manifest.json"
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

resource "jellyfin_plugin_repository" "jellyfin_security" {
  enabled = true
  name    = "Jellyfin Security"
  url     = local.jellyfin_security_plugin_repository_url
}

resource "jellyfin_plugin" "jellyfin_security" {
  name           = "Jellyfin Security"
  repository_url = local.jellyfin_security_plugin_repository_url
}

resource "jellyfin_security_plugin_configuration" "jellyfin_security" {
  plugin_id = jellyfin_plugin.jellyfin_security.id

  block_empty_password_login     = true
  disable_password_login         = true
  allow_admin_password_login     = false
  hide_builtin_two_factor_button = true
  hide_builtin_passkey_button    = true
  trust_forwarded_for            = true
  trusted_proxy_cidrs            = ["10.244.0.0/16"]

  oidc_providers = [
    {
      id                          = "authentik"
      display_name                = "Authentik"
      preset                      = "authentik"
      discovery_url               = "https://auth.${var.authentik_domain}/application/o/jellyfin/.well-known/openid-configuration"
      client_id                   = data.bitwarden-secrets_secret.jellyfin_oauth_client_id.value
      client_secret               = data.bitwarden-secrets_secret.jellyfin_oauth_client_secret.value
      scopes                      = ["openid", "profile", "email", "groups"]
      allowed_groups              = ["watchers", "admins"]
      admin_groups                = ["admins"]
      allow_admin_group_elevation = true
      auto_create_users           = true
      omit_prompt_login           = true
      force_https                 = false
      allow_private_networks      = true
      additional_allowed_cidrs    = ["192.168.0.0/16"]
    }
  ]
}

resource "jellyfin_networking_configuration" "this" {
  known_proxies                  = ["10.244.0.0/16"]
  published_server_uri_by_subnet = ["all=https://watch.${var.authentik_domain}"]
}

resource "jellyfin_branding_configuration" "this" {
  custom_css = file("${path.module}/files/jellyfin/branding/custom.css")
}

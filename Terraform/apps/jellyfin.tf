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

resource "jellyfin_plugin" "sso_auth" {
  name           = "SSO-Auth"
  version        = "4.0.0.4"
  repository_url = local.jellyfin_sso_plugin_repository_url
}

# The raw-JSON resource is superseded by the typed one; drop it from state
# without touching the server (its Delete is a no-op anyway).
removed {
  from = jellyfin_plugin_configuration.sso_auth
  lifecycle {
    destroy = false
  }
}

resource "jellyfin_sso_plugin_configuration" "sso_auth" {
  plugin_id = jellyfin_plugin.sso_auth.id

  oid_configs = {
    authentik = {
      oid_endpoint              = "https://auth.${var.authentik_domain}/application/o/jellyfin"
      oid_client_id             = data.bitwarden-secrets_secret.jellyfin_oauth_client_id.value
      oid_secret                = data.bitwarden-secrets_secret.jellyfin_oauth_client_secret.value
      enabled                   = true
      enable_authorization      = true
      enable_all_folders        = true
      enabled_folders           = []
      admin_roles               = ["admins"]
      roles                     = ["watchers", "admins"]
      enable_folder_roles       = false
      enable_live_tv_roles      = false
      enable_live_tv            = false
      enable_live_tv_management = false
      live_tv_roles             = []
      live_tv_management_roles  = []
      folder_role_mapping       = []
      role_claim                = "groups"
      oid_scopes                = ["groups"]
      default_provider          = ""
      default_username_claim    = "preferred_username"
      scheme_override           = "https"
      new_path                  = true
      avatar_url_format         = ""
      disable_https             = false
      disable_pushed_authorization = false
      do_not_validate_endpoints = false
      do_not_validate_issuer_name = false
      do_not_load_profile       = false
    }
  }

  saml_configs = {}
}

resource "jellyfin_networking_configuration" "this" {
  base_url                              = ""
  enable_https                          = false
  require_https                         = false
  certificate_path                      = ""
  certificate_password                  = ""
  internal_http_port                    = 8096
  internal_https_port                   = 8920
  public_http_port                      = 8096
  public_https_port                     = 8920
  auto_discovery                        = true
  enable_upnp                           = false
  enable_ipv4                           = true
  enable_ipv6                           = false
  enable_remote_access                  = true
  local_network_subnets                 = []
  local_network_addresses               = []
  known_proxies                         = ["10.244.0.0/16"]
  ignore_virtual_interfaces             = true
  virtual_interface_names               = ["veth"]
  enable_published_server_uri_by_request = true
  published_server_uri_by_subnet        = ["all=https://watch.${var.authentik_domain}"]
  remote_ip_filter                      = []
  is_remote_ip_filter_blacklist         = false
}

resource "jellyfin_branding_configuration" "this" {
  login_disclaimer     = file("${path.module}/files/jellyfin/branding/disclaimer.html")
  custom_css           = file("${path.module}/files/jellyfin/branding/custom.css")
  splashscreen_enabled = false
}

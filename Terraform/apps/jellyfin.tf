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
  name    = "SSO-Auth"
  version = "4.0.0.4"
}

resource "jellyfin_plugin_configuration" "sso_auth" {
  plugin_id = jellyfin_plugin.sso_auth.id

  configuration_json = jsonencode({
    SamlConfigs = {}
    OidConfigs = {
      authentik = {
        OidEndpoint                = "https://auth.${var.authentik_domain}/application/o/jellyfin"
        OidClientId                = data.bitwarden-secrets_secret.jellyfin_oidc_client_id.value
        OidSecret                  = data.bitwarden-secrets_secret.jellyfin_oidc_client_secret.value
        Enabled                    = true
        EnableAuthorization        = true
        EnableAllFolders           = true
        EnabledFolders             = []
        AdminRoles                 = ["admins"]
        Roles                      = []
        EnableFolderRoles          = false
        EnableLiveTvRoles          = false
        EnableLiveTv               = false
        EnableLiveTvManagement     = false
        FolderRoleMapping          = []
        RoleClaim                  = "groups"
        OidScopes                  = ["groups"]
        DefaultProvider            = ""
        SchemeOverride             = "https"
        NewPath                    = false
        CanonicalLinks             = {}
        DefaultUsernameClaim       = "preferred_username"
        DisableHttps               = false
        DisablePushedAuthorization = false
        DoNotValidateEndpoints     = false
        DoNotValidateIssuerName    = false
        DoNotLoadProfile           = false
      }
    }
  })
}

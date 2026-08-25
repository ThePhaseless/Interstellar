data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default-invalidation-flow" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_certificate_key_pair" "default" {
  name = "authentik Self-signed Certificate"
}

# OAuth2 scope mappings (renamed in provider v2025.x)
data "authentik_property_mapping_provider_scope" "oauth2" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-profile",
  ]
}

# Google OAuth enrollment creates users as "external" by default, which blocks
# access to the Authentik admin interface, so this flow overrides the user_write
# stage to set user_type=internal.

resource "authentik_flow" "google_enrollment" {
  name               = "google-source-enrollment"
  title              = "Enroll via Google"
  slug               = "google-source-enrollment"
  designation        = "enrollment"
  policy_engine_mode = "any"
}

resource "authentik_stage_user_write" "google_enrollment" {
  name      = "google-enrollment-user-write"
  user_type = "internal"
}

resource "authentik_flow_stage_binding" "google_enrollment_write" {
  target = authentik_flow.google_enrollment.uuid
  stage  = authentik_stage_user_write.google_enrollment.id
  order  = 10
}

# The stock default-source-authentication flow only logs the user in, so mapped
# properties are recomputed each login and discarded. The user_write below is what
# persists them, which also refreshes name and email from Google on every sign-in.
resource "authentik_flow" "google_source_auth" {
  name               = "google-source-authentication"
  title              = "Sign in with Google"
  slug               = "google-source-authentication"
  designation        = "authentication"
  policy_engine_mode = "any"
  # Matches the stock source-authentication flow this replaces; without it an
  # already-signed-in user can re-enter the login flow.
  authentication = "require_unauthenticated"
}

# never_create: this flow only ever runs with an already-linked user pending, and
# create_when_required would silently enroll around the enrollment flow.
resource "authentik_stage_user_write" "google_source_auth" {
  name               = "google-auth-user-write"
  user_creation_mode = "never_create"
}

resource "authentik_flow_stage_binding" "google_source_auth_write" {
  target = authentik_flow.google_source_auth.uuid
  stage  = authentik_stage_user_write.google_source_auth.id
  order  = 10
}

resource "authentik_stage_user_login" "google_source_auth" {
  name = "google-auth-user-login"
}

resource "authentik_flow_stage_binding" "google_source_auth_login" {
  target = authentik_flow.google_source_auth.uuid
  stage  = authentik_stage_user_login.google_source_auth.id
  order  = 20
}

# Authentik's Google source type forwards only email and name from userinfo, so the
# `picture` claim is dropped unless a mapping keeps it.
resource "authentik_property_mapping_source_oauth" "google_avatar" {
  name       = "google-avatar"
  expression = <<-EOT
    return {"attributes": {"avatar": info.get("picture")}}
  EOT
}

resource "authentik_source_oauth" "google" {
  access_token_url  = "https://oauth2.googleapis.com/token"
  authorization_url = "https://accounts.google.com/o/oauth2/v2/auth"
  oidc_jwks_url     = "https://www.googleapis.com/oauth2/v3/certs"
  profile_url       = "https://openidconnect.googleapis.com/v1/userinfo"

  name                = "Google"
  slug                = "google"
  authentication_flow = authentik_flow.google_source_auth.uuid
  enrollment_flow     = authentik_flow.google_enrollment.uuid

  provider_type   = "google"
  consumer_key    = data.bitwarden-secrets_secret.google_oauth_client_id.value
  consumer_secret = data.bitwarden-secrets_secret.google_oauth_client_secret.value

  promoted            = true
  user_matching_mode  = "email_link"
  group_matching_mode = "identifier"

  property_mappings = [authentik_property_mapping_source_oauth.google_avatar.id]
}

# Tried left to right per user: the Google picture once the mapping has captured one,
# Gravatar for accounts that have not signed in since, generated initials otherwise.
resource "authentik_system_settings" "default" {
  avatars = "attributes.avatar,gravatar,initials"
}

# The owner must have logged in via Google at least once. Until then the lookup
# returns nothing and the group is created empty, filling in on the next apply.
data "authentik_users" "owner" {
  email = data.bitwarden-secrets_secret.owner_email.value
}

resource "authentik_group" "admins" {
  name         = "admins"
  is_superuser = true
  users        = length(data.authentik_users.owner.users) > 0 ? [data.authentik_users.owner.users[0].pk] : []

  lifecycle {
    ignore_changes = [users]
  }
}

# Trusted people. Every policy that accepts vips also accepts admins, so admins
# are effectively a superset of vips without relying on Authentik group nesting
# (the groups claim sent to Grafana/ArgoCD/Jellyfin lists direct memberships only).
resource "authentik_group" "vips" {
  name  = "vips"
  users = []

  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_flow" "google_only_auth" {
  name               = "google-only-authentication"
  title              = "Sign in with Google"
  slug               = "google-only-authentication"
  designation        = "authentication"
  policy_engine_mode = "any"
}

resource "authentik_stage_identification" "google_only" {
  name        = "google-only-identification"
  user_fields = []
  sources     = [authentik_source_oauth.google.uuid]
}

resource "authentik_flow_stage_binding" "google_only_id" {
  target = authentik_flow.google_only_auth.uuid
  stage  = authentik_stage_identification.google_only.id
  order  = 10
}

resource "authentik_brand" "default" {
  domain              = "authentik-default"
  default             = true
  flow_authentication = authentik_flow.google_only_auth.uuid
  branding_title      = "Nerine"
  branding_favicon    = "/static/dist/assets/icons/icon.png"
  branding_logo       = "/static/dist/assets/icons/icon_left_brand.svg"
}

resource "authentik_provider_proxy" "private" {
  name               = "private-proxy"
  mode               = "forward_domain"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  external_host      = "https://auth.${var.authentik_domain}"
  cookie_domain      = var.authentik_domain

  access_token_validity  = "hours=24"
  refresh_token_validity = "days=30"
}

# Public: Any Google account — copyparty only.
# MUST stay forward_single: two forward_domain providers sharing an external_host
# can't be multiplexed by the outpost, so this zero-policy provider won every host
# and the access policy never fired.
# Off the shared private proxy so watchers reach Seerr without also reaching the
# *arr stack and cluster tooling. forward_single for the reason on
# authentik_provider_proxy.public.
resource "authentik_provider_proxy" "seerr" {
  name               = "seerr-proxy"
  mode               = "forward_single"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  external_host      = "https://add.${var.authentik_domain}"
  # Authentik's API refuses to clear this; inert in forward_single mode.
  cookie_domain = var.authentik_domain

  access_token_validity  = "hours=24"
  refresh_token_validity = "days=30"
}

resource "authentik_provider_proxy" "public" {
  name               = "public-proxy"
  mode               = "forward_single"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  external_host      = "https://files.${var.authentik_domain}"
  # Authentik's API refuses to clear this; inert in forward_single mode.
  cookie_domain = var.authentik_domain

  access_token_validity  = "hours=24"
  refresh_token_validity = "days=30"
}

resource "authentik_application" "private" {
  name              = "Private Services"
  slug              = "private-services"
  protocol_provider = authentik_provider_proxy.private.id
  meta_description  = "Forward-auth carrier for the *arr stack, monitoring and cluster tooling. Not a launchable app."
  meta_launch_url   = "blank://blank"
}

# There is no separate "public" application: Authentik forbids two applications
# on one provider, so authentik_application.copyparty owns the public proxy.

# Access policies. Membership is managed in the Authentik web UI — adding a
# person to a group needs no Terraform change.

resource "authentik_policy_expression" "vips_or_admins" {
  name       = "vips-or-admins"
  expression = <<-EOT
    return (
        ak_is_group_member(request.user, name="vips")
        or ak_is_group_member(request.user, name="admins")
    )
  EOT
}

resource "authentik_policy_expression" "watchers_vips_or_admins" {
  name       = "watchers-vips-or-admins"
  expression = <<-EOT
    return (
        ak_is_group_member(request.user, name="watchers")
        or ak_is_group_member(request.user, name="vips")
        or ak_is_group_member(request.user, name="admins")
    )
  EOT
}

resource "authentik_policy_expression" "photos_or_admins" {
  name       = "photos-or-admins"
  expression = <<-EOT
    return (
        ak_is_group_member(request.user, name="photos")
        or ak_is_group_member(request.user, name="admins")
    )
  EOT
}

resource "authentik_policy_binding" "private_access" {
  target = authentik_application.private.uuid
  policy = authentik_policy_expression.vips_or_admins.id
  order  = 0
}

# Authentik owns the embedded outpost's lifecycle; this resource only assigns
# providers to it. No service_connection — it runs inside authentik-server.
resource "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
  protocol_providers = [
    authentik_provider_proxy.private.id,
    authentik_provider_proxy.public.id,
    authentik_provider_proxy.seerr.id,
  ]
  config = jsonencode({
    authentik_host                 = "https://auth.${var.authentik_domain}/"
    object_naming_template         = "ak-outpost-%(name)s"
    kubernetes_namespace           = "authentik"
    kubernetes_disabled_components = ["deployment", "secret", "service", "prometheus servicemonitor", "ingress", "traefik middleware"]
  })
}

resource "authentik_provider_oauth2" "grafana" {
  name               = "Grafana"
  client_id          = "grafana"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id
  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.oauth2.ids,
    [authentik_property_mapping_provider_scope.groups.id]
  )
  allowed_redirect_uris = [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://grafana.${var.authentik_domain}/login/generic_oauth"
    }
  ]
}

resource "authentik_application" "grafana" {
  name              = "Grafana"
  slug              = "grafana"
  protocol_provider = authentik_provider_oauth2.grafana.id
  meta_description  = "Dashboards and graphs showing how the server is doing"
  meta_launch_url   = "https://grafana.${var.authentik_domain}"
  meta_icon         = "${local.icon_base}/grafana.svg"
}

# Grafana maps the groups claim to a role itself: admins land on Admin,
# everyone else (vips included) falls through to Viewer.
resource "authentik_policy_binding" "grafana_access" {
  target = authentik_application.grafana.uuid
  policy = authentik_policy_expression.vips_or_admins.id
  order  = 0
}

resource "bitwarden-secrets_secret" "grafana_oauth_client_id" {
  key        = "authentik-grafana-client-id"
  value      = authentik_provider_oauth2.grafana.client_id
  project_id = local.bitwarden_generated_project_id
  note       = "Grafana OIDC client ID (via Authentik). Managed by Terraform."
}

resource "bitwarden-secrets_secret" "grafana_oauth_client_secret" {
  key        = "authentik-grafana-client-secret"
  value      = authentik_provider_oauth2.grafana.client_secret
  project_id = local.bitwarden_generated_project_id
  note       = "Grafana OIDC client secret (via Authentik). Managed by Terraform."
}

resource "authentik_provider_oauth2" "immich" {
  name               = "Immich"
  client_id          = "immich"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id
  property_mappings  = data.authentik_property_mapping_provider_scope.oauth2.ids
  allowed_redirect_uris = [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://photos.${var.authentik_domain}/auth/login"
    },
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://photos.${var.authentik_domain}/user-settings"
    },
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "app.immich:///oauth-callback"
    }
  ]
}

resource "authentik_application" "immich" {
  name              = "Immich"
  slug              = "immich"
  protocol_provider = authentik_provider_oauth2.immich.id
  meta_description  = "Browse, back up and share your photos and videos"
  meta_launch_url   = "https://photos.${var.authentik_domain}/auth/login?autoLaunch=1"
  meta_icon         = "${local.icon_base}/immich.svg"
}

resource "bitwarden-secrets_secret" "immich_oauth_client_id" {
  key        = "authentik-immich-client-id"
  value      = authentik_provider_oauth2.immich.client_id
  project_id = local.bitwarden_generated_project_id
  note       = "Immich OIDC client ID (via Authentik). Managed by Terraform."
}

resource "bitwarden-secrets_secret" "immich_oauth_client_secret" {
  key        = "authentik-immich-client-secret"
  value      = authentik_provider_oauth2.immich.client_secret
  project_id = local.bitwarden_generated_project_id
  note       = "Immich OIDC client secret (via Authentik). Managed by Terraform."
}

# Public share links bypass auth; this only gates OIDC login. Immich has
# autoRegister enabled, so a photos member self-provisions on first login.
resource "authentik_policy_binding" "immich_access" {
  target = authentik_application.immich.uuid
  policy = authentik_policy_expression.photos_or_admins.id
  order  = 0
}

# "watchers" → Jellyfin and Seerr login, "writers" → Copyparty upload, "photos" → Immich login.
# Created empty; manage membership in the Authentik UI.

resource "authentik_group" "watchers" {
  name  = "watchers"
  users = []

  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_group" "writers" {
  name  = "writers"
  users = []

  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_group" "photos" {
  name  = "photos"
  users = []

  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_property_mapping_provider_scope" "groups" {
  name        = "Group Membership"
  scope_name  = "groups"
  description = "Maps user group memberships and username for RBAC"
  expression  = "return {\"groups\": [group.name for group in user.groups.all()], \"preferred_username\": user.username}"
}

resource "authentik_provider_oauth2" "jellyfin" {
  name               = "Jellyfin"
  client_id          = "jellyfin"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id
  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.oauth2.ids,
    [authentik_property_mapping_provider_scope.groups.id]
  )
  allowed_redirect_uris = [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://watch.${var.authentik_domain}/TwoFactorAuth/Oidc/Callback/authentik"
    },
    {
      # Traefik terminates TLS, so the plugin sees http:// and uses it as redirect_uri
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "http://watch.${var.authentik_domain}/TwoFactorAuth/Oidc/Callback/authentik"
    },
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://localhost:8096/TwoFactorAuth/Oidc/Callback/authentik"
    },
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "http://localhost:8096/TwoFactorAuth/Oidc/Callback/authentik"
    },
    {
      # https only: the plugin drops a post_logout_redirect_uri that is not absolute https.
      matching_mode     = "strict"
      redirect_uri_type = "logout"
      url               = "https://watch.${var.authentik_domain}/TwoFactorAuth/Oidc/LoggedOut"
    }
  ]
}

resource "authentik_application" "jellyfin" {
  name              = "Jellyfin"
  slug              = "jellyfin"
  protocol_provider = authentik_provider_oauth2.jellyfin.id
  meta_description  = "Stream the movies, shows and music on the server"
  meta_launch_url   = "https://watch.${var.authentik_domain}"
  meta_icon         = "${local.icon_base}/jellyfin.svg"
}

resource "bitwarden-secrets_secret" "jellyfin_oauth_client_id" {
  key        = "authentik-jellyfin-client-id"
  value      = authentik_provider_oauth2.jellyfin.client_id
  project_id = local.bitwarden_generated_project_id
  note       = "Jellyfin OIDC client ID (via Authentik). Managed by Terraform."
}

resource "bitwarden-secrets_secret" "jellyfin_oauth_client_secret" {
  key        = "authentik-jellyfin-client-secret"
  value      = authentik_provider_oauth2.jellyfin.client_secret
  project_id = local.bitwarden_generated_project_id
  note       = "Jellyfin OIDC client secret (via Authentik). Managed by Terraform."
}

resource "authentik_policy_binding" "jellyfin_access" {
  target = authentik_application.jellyfin.uuid
  policy = authentik_policy_expression.watchers_vips_or_admins.id
  order  = 0
}

# No access policy: any Google account may sign in, and copyparty applies its own
# volume ACLs from the X-authentik-groups header (writers upload, admins full).

resource "authentik_application" "copyparty" {
  name              = "Copyparty"
  slug              = "copyparty"
  protocol_provider = authentik_provider_proxy.public.id
  meta_description  = "Upload, browse and share files"
  meta_launch_url   = "https://files.${var.authentik_domain}"
  meta_icon         = "${local.icon_base}/copyparty.svg"
}

locals {
  icon_base = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg"

  private_service_apps = {
    sonarr = {
      name        = "Sonarr"
      host        = "sonarr"
      description = "Follows TV series and fetches new episodes as they air"
      icon        = "${local.icon_base}/sonarr.svg"
    }
    radarr = {
      name        = "Radarr"
      host        = "radarr"
      description = "Finds and downloads films for the library"
      icon        = "${local.icon_base}/radarr.svg"
    }
    bazarr = {
      name        = "Bazarr"
      host        = "bazarr"
      description = "Finds and downloads subtitles for the library"
      icon        = "${local.icon_base}/bazarr.svg"
    }
    prowlarr = {
      name        = "Prowlarr"
      host        = "prowlarr"
      description = "Manages the sites the download apps search"
      icon        = "${local.icon_base}/prowlarr.svg"
    }
    adguard = {
      name        = "AdGuard"
      host        = "dns"
      description = "Blocks ads and trackers across the whole network"
      icon        = "${local.icon_base}/adguard-home.svg"
    }
    qbittorrent = {
      name        = "qBittorrent"
      host        = "qbittorrent"
      description = "Shows what is downloading right now and how fast"
      icon        = "${local.icon_base}/qbittorrent.svg"
    }
    longhorn = {
      name        = "Longhorn"
      host        = "longhorn"
      description = "Manages the server's disks, volumes and backups"
      # selfh.st has no longhorn icon; dashboard-icons does.
      icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/longhorn.svg"
    }
    traefik = {
      name        = "Traefik"
      host        = "traefik"
      description = "Routes incoming traffic to the right service"
      icon        = "${local.icon_base}/traefik.svg"
    }
  }
}

resource "authentik_application" "private_service" {
  for_each = local.private_service_apps

  name             = each.value.name
  slug             = each.key
  meta_description = each.value.description
  meta_launch_url  = "https://${each.value.host}.${var.authentik_domain}"
  meta_icon        = each.value.icon
}

resource "authentik_application" "seerr" {
  name              = "Seerr"
  slug              = "seerr"
  protocol_provider = authentik_provider_proxy.seerr.id
  meta_description  = "Ask for a film or series to be added to the library"
  meta_launch_url   = "https://add.${var.authentik_domain}"
  meta_icon         = "${local.icon_base}/seerr.svg"
}

resource "authentik_policy_binding" "seerr_access" {
  target = authentik_application.seerr.uuid
  policy = authentik_policy_expression.watchers_vips_or_admins.id
  order  = 0
}

resource "authentik_policy_binding" "private_service_access" {
  for_each = local.private_service_apps

  target = authentik_application.private_service[each.key].uuid
  policy = authentik_policy_expression.vips_or_admins.id
  order  = 0
}

resource "authentik_provider_oauth2" "argocd" {
  name               = "ArgoCD"
  client_id          = "argocd"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id
  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.oauth2.ids,
    [authentik_property_mapping_provider_scope.groups.id]
  )
  allowed_redirect_uris = [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://argocd.${var.authentik_domain}/auth/callback"
    }
  ]
}

resource "authentik_application" "argocd" {
  name              = "ArgoCD"
  slug              = "argocd"
  protocol_provider = authentik_provider_oauth2.argocd.id
  meta_description  = "Deploys and keeps every service on the cluster up to date"
  meta_launch_url   = "https://argocd.${var.authentik_domain}"
  meta_icon         = "${local.icon_base}/argo-cd.svg"
}

# Reaching the app is gated here; the role once inside comes from
# argocd-rbac-cm (admins → admin, vips → readonly).
resource "authentik_policy_binding" "argocd_access" {
  target = authentik_application.argocd.uuid
  policy = authentik_policy_expression.vips_or_admins.id
  order  = 0
}

resource "bitwarden-secrets_secret" "argocd_oidc_client_secret" {
  key        = "authentik-argocd-client-secret"
  value      = authentik_provider_oauth2.argocd.client_secret
  project_id = local.bitwarden_generated_project_id
  note       = "ArgoCD OIDC client secret (via Authentik). Managed by Terraform."
}

resource "authentik_stage_prompt_field" "username" {
  name      = "enrollment-field-username"
  field_key = "username"
  label     = "Username"
  type      = "username" # Automatically validates for uniqueness
  required  = true
}

resource "authentik_stage_prompt" "google_enrollment_prompt" {
  name   = "google-enrollment-prompt"
  fields = [authentik_stage_prompt_field.username.id]
}

resource "authentik_flow_stage_binding" "google_enrollment_prompt_binding" {
  target = authentik_flow.google_enrollment.uuid
  stage  = authentik_stage_prompt.google_enrollment_prompt.id
  order  = 5 # Must run BEFORE the user_write stage (order 10)
}

resource "authentik_stage_user_login" "google_enrollment_login" {
  name = "google-enrollment-user-login"
}

resource "authentik_flow_stage_binding" "google_enrollment_login_binding" {
  target = authentik_flow.google_enrollment.uuid
  stage  = authentik_stage_user_login.google_enrollment_login.id
  order  = 20 # Must run AFTER the user_write stage (order 10)
}

resource "authentik_event_transport" "discord" {
  name = "discord"
  mode = "webhook_slack"
  # Discord accepts Slack-shaped payloads only on the /slack variant of the URL.
  webhook_url = "${data.bitwarden-secrets_secret.discord_webhook_url.value}/slack"
}

# EventMatcherPolicy.passes ANDs every criterion it has set.
resource "authentik_policy_event_matcher" "user_created" {
  name   = "user-created"
  action = "model_created"
  model  = "authentik_core.user"
}

resource "authentik_event_rule" "user_created" {
  name              = "user-created"
  transports        = [authentik_event_transport.discord.id]
  destination_group = authentik_group.admins.id
  severity          = "notice"
}

resource "authentik_policy_binding" "user_created" {
  target = authentik_event_rule.user_created.id
  policy = authentik_policy_event_matcher.user_created.id
  order  = 0
}

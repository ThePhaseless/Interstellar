data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default-invalidation-flow" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_flow" "default-source-authentication" {
  slug = "default-source-authentication"
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

resource "authentik_source_oauth" "google" {
  access_token_url  = "https://oauth2.googleapis.com/token"
  authorization_url = "https://accounts.google.com/o/oauth2/v2/auth"
  oidc_jwks_url     = "https://www.googleapis.com/oauth2/v3/certs"
  profile_url       = "https://openidconnect.googleapis.com/v1/userinfo"

  name                = "Google"
  slug                = "google"
  authentication_flow = data.authentik_flow.default-source-authentication.id
  enrollment_flow     = authentik_flow.google_enrollment.uuid

  provider_type   = "google"
  consumer_key    = data.bitwarden-secrets_secret.google_oauth_client_id.value
  consumer_secret = data.bitwarden-secrets_secret.google_oauth_client_secret.value

  promoted            = true
  user_matching_mode  = "email_link"
  group_matching_mode = "identifier"
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
  meta_description  = "VIP email-restricted homelab services (homepage, *arr stack, monitoring, etc.)"
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
  meta_description  = "Grafana observability dashboard"
  meta_launch_url   = "https://grafana.${var.authentik_domain}"
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
  meta_description  = "Immich photo management"
  meta_launch_url   = "https://photos.${var.authentik_domain}/auth/login?autoLaunch=1"
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

# "watchers" → Jellyfin login, "writers" → Copyparty upload, "photos" → Immich login.
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
    }
  ]
}

resource "authentik_application" "jellyfin" {
  name              = "Jellyfin"
  slug              = "jellyfin"
  protocol_provider = authentik_provider_oauth2.jellyfin.id
  meta_description  = "Jellyfin media server with SSO authentication"
  meta_launch_url   = "https://watch.${var.authentik_domain}"
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
  meta_description  = "File server: read=any Google user, write=writers group, admin=Admins group"
  meta_launch_url   = "https://files.${var.authentik_domain}"
}

# qBittorrent has no application of its own: its IngressRoute carries the shared
# authentik forward-auth middleware, which resolves to the private proxy provider.

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
  meta_description  = "GitOps continuous delivery for Kubernetes"
  meta_launch_url   = "https://argocd.${var.authentik_domain}"
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

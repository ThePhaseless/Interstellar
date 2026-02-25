# =============================================================================
# Authentik Configuration — Identity Provider
# =============================================================================
# Configures Authentik as the central IdP with group-based RBAC.
# Two proxy providers (forward_domain mode):
#   - "private": Admins group only (homepage, *arr stack, qBittorrent, dashboards)
#   - "public": Any Google account (Jellyseerr, Copyparty)
# Native OIDC providers: Grafana, Immich, Jellyfin
# Google OAuth is the only login source (no username/password).
# Groups managed manually in Authentik UI — no Terraform changes needed to add users.

# -----------------------------------------------------------------------------
# Data Sources — Built-in Flows
# -----------------------------------------------------------------------------

data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default-invalidation-flow" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_flow" "default-source-authentication" {
  slug = "default-source-authentication"
}

# Self-signed certificate for JWT signing
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

# -----------------------------------------------------------------------------
# Custom Enrollment Flow — Creates users as "internal" type
# -----------------------------------------------------------------------------
# Google OAuth enrollment creates users as "external" by default, which blocks
# access to the Authentik admin interface. This custom flow overrides the
# user_write stage to set user_type=internal for all Google-enrolled users.

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

# -----------------------------------------------------------------------------
# Google OAuth Source — The only login method
# -----------------------------------------------------------------------------

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

  # Show on login page + auto-enroll new users
  promoted            = true
  user_matching_mode  = "email_link"
  group_matching_mode = "identifier"
}

# -----------------------------------------------------------------------------
# Owner Account — Superuser via owner-email Bitwarden secret
# -----------------------------------------------------------------------------
# Look up the existing user by email (must have logged in via Google at least once).
# If the user hasn't logged in yet, the group is created empty and will be
# populated on the next apply after the user authenticates via Google.
data "authentik_users" "owner" {
  email = data.bitwarden-secrets_secret.owner_email.value
}

resource "authentik_group" "admins" {
  name         = "admins"
  is_superuser = true
  users        = length(data.authentik_users.owner.users) > 0 ? [data.authentik_users.owner.users[0].pk] : []
}

# -----------------------------------------------------------------------------
# Google-Only Authentication Flow — No username/password
# -----------------------------------------------------------------------------

resource "authentik_flow" "google_only_auth" {
  name               = "google-only-authentication"
  title              = "Sign in with Google"
  slug               = "google-only-authentication"
  designation        = "authentication"
  policy_engine_mode = "any"
}

# Identification stage showing only the Google source button (no user_fields)
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

# Set Google-only flow as the default authentication flow via brand
resource "authentik_brand" "default" {
  domain              = "authentik-default"
  default             = true
  flow_authentication = authentik_flow.google_only_auth.uuid
  branding_title      = "Nerine"
  branding_favicon    = "/static/dist/assets/icons/icon.png"
  branding_logo       = "/static/dist/assets/icons/icon_left_brand.svg"
}

# -----------------------------------------------------------------------------
# Proxy Providers — Forward Auth (Domain Level)
# -----------------------------------------------------------------------------

# Private: VIP email-restricted access
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

# Public: Any Google account
resource "authentik_provider_proxy" "public" {
  name               = "public-proxy"
  mode               = "forward_domain"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  external_host      = "https://auth.${var.authentik_domain}"
  cookie_domain      = var.authentik_domain

  access_token_validity  = "hours=24"
  refresh_token_validity = "days=30"
}

# -----------------------------------------------------------------------------
# Applications — Linked to providers
# -----------------------------------------------------------------------------

resource "authentik_application" "private" {
  name              = "Private Services"
  slug              = "private-services"
  protocol_provider = authentik_provider_proxy.private.id
  meta_description  = "VIP email-restricted homelab services (homepage, *arr stack, monitoring, etc.)"
}

# NOTE: authentik_application.public is covered by authentik_application.copyparty
# (both would bind to the same public proxy provider, which Authentik forbids).
# Copyparty serves as the canonical public-proxy application in the app portal.

# -----------------------------------------------------------------------------
# Access Policies — Group-based RBAC
# -----------------------------------------------------------------------------
# admins_only:         requires membership in the "Admins" group
# watchers_or_admins:  requires "watchers" OR "Admins" group (Jellyfin)
# Add users to groups in the Authentik web UI — no Terraform changes needed.

resource "authentik_policy_expression" "admins_only" {
  name       = "admins-only"
  expression = <<-EOT
    return ak_is_group_member(request.user, name="admins")
  EOT
}

resource "authentik_policy_expression" "watchers_or_admins" {
  name       = "watchers-or-admins"
  expression = <<-EOT
    return (
        ak_is_group_member(request.user, name="watchers")
        or ak_is_group_member(request.user, name="admins")
    )
  EOT
}

# Bind admins policy to private (proxy) application — covers homepage, *arr, longhorn, traefik
resource "authentik_policy_binding" "private_admins" {
  target = authentik_application.private.uuid
  policy = authentik_policy_expression.admins_only.id
  order  = 0
}

# -----------------------------------------------------------------------------
# Embedded Outpost — Uses the proxy providers
# -----------------------------------------------------------------------------
# The embedded outpost is automatically available in Authentik.
# We just need to assign our providers to it.

# NOTE: The embedded outpost is managed by Authentik itself.
# We use the resource to assign our proxy providers to it.
# No service_connection needed — the embedded outpost runs inside authentik-server.
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

# -----------------------------------------------------------------------------
# Grafana OIDC Provider
# -----------------------------------------------------------------------------

resource "authentik_provider_oauth2" "grafana" {
  name               = "Grafana"
  client_id          = "grafana"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id
  property_mappings  = data.authentik_property_mapping_provider_scope.oauth2.ids
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://grafana.${var.authentik_domain}/login/generic_oauth"
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

# Bind admins policy to Grafana
resource "authentik_policy_binding" "grafana_admins" {
  target = authentik_application.grafana.uuid
  policy = authentik_policy_expression.admins_only.id
  order  = 0
}

# Store Grafana OIDC credentials in Bitwarden for Kubernetes to consume
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

# -----------------------------------------------------------------------------
# Immich OIDC Provider
# -----------------------------------------------------------------------------

resource "authentik_provider_oauth2" "immich" {
  name               = "Immich"
  client_id          = "immich"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id
  property_mappings  = data.authentik_property_mapping_provider_scope.oauth2.ids
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://photos.${var.authentik_domain}/auth/login"
    },
    {
      matching_mode = "strict"
      url           = "https://photos.${var.authentik_domain}/user-settings"
    },
    {
      matching_mode = "strict"
      url           = "app.immich:///oauth-callback"
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

# Store Immich OIDC credentials in Bitwarden for Kubernetes to consume
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

# Bind admins policy to Immich — only admins can log in via OIDC; public share links bypass auth
resource "authentik_policy_binding" "immich_admins" {
  target = authentik_application.immich.uuid
  policy = authentik_policy_expression.admins_only.id
  order  = 0
}

# -----------------------------------------------------------------------------
# Jellyfin Groups — RBAC via Authentik group membership
# -----------------------------------------------------------------------------
# "watchers" → allowed to log into Jellyfin (9p4 plugin roleClaim: roles=["watchers"])
# "writers"  → Copyparty upload access (read is open to any Google-authenticated user)
#
# Owner is auto-seeded into watchers. Add other users manually in Authentik UI.
# "Admins" group also gets Jellyfin access via the watchers_or_admins policy.

resource "authentik_group" "watchers" {
  name  = "watchers"
  users = length(data.authentik_users.owner.users) > 0 ? [data.authentik_users.owner.users[0].pk] : []
}

resource "authentik_group" "writers" {
  name  = "writers"
  users = []
}

# -----------------------------------------------------------------------------
# Jellyfin OIDC Provider — SSO with automatic account creation
# -----------------------------------------------------------------------------

# Group membership scope mapping (required for RBAC support)
resource "authentik_property_mapping_provider_scope" "jellyfin_groups" {
  name        = "Jellyfin Group Membership"
  scope_name  = "groups"
  description = "Maps user group memberships for Jellyfin RBAC"
  expression  = "return [group.name for group in user.ak_groups.all()]"
}

resource "authentik_provider_oauth2" "jellyfin" {
  name               = "Jellyfin"
  client_id          = "jellyfin"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id
  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.oauth2.ids,
    [authentik_property_mapping_provider_scope.jellyfin_groups.id]
  )
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://watch.${var.authentik_domain}/sso/OID/redirect/authentik"
    },
    {
      # Traefik terminates TLS, so the SSO plugin sees http:// and uses it as redirect_uri
      matching_mode = "strict"
      url           = "http://watch.${var.authentik_domain}/sso/OID/redirect/authentik"
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

# Store Jellyfin OIDC credentials in Bitwarden for Kubernetes to consume
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

# Bind watchers_or_admins policy to Jellyfin — only watchers/Admins can log in via SSO
resource "authentik_policy_binding" "jellyfin_watchers" {
  target = authentik_application.jellyfin.uuid
  policy = authentik_policy_expression.watchers_or_admins.id
  order  = 0
}

# -----------------------------------------------------------------------------
# MCPJungle — Tailscale-only, no Authentik application needed
# -----------------------------------------------------------------------------
# mcp.nerine.dev is gated entirely by Traefik's tailscale-only IP middleware.
# No Authentik application is registered for it.

# -----------------------------------------------------------------------------
# Copyparty — Proxy application (any Google account)
# -----------------------------------------------------------------------------
# Copyparty manages fine-grained permissions internally via IdP group headers
# (X-authentik-groups): @acct=read, @writers=read+write, @Admins=full admin.
# No Authentik-level access policy needed here.

resource "authentik_application" "copyparty" {
  name              = "Copyparty"
  slug              = "copyparty"
  protocol_provider = authentik_provider_proxy.public.id
  meta_description  = "File server: read=any Google user, write=writers group, admin=Admins group"
  meta_launch_url   = "https://files.${var.authentik_domain}"
}

# -----------------------------------------------------------------------------
# qBittorrent — access is controlled via the private-chain Traefik middleware,
# which validates auth through authentik_application.private (private-services).
# A separate Authentik application is not needed since qBittorrent shares the
# private proxy provider (Authentik forbids one provider bound to multiple apps).

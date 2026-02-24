# =============================================================================
# Authentik Configuration — Identity Provider
# =============================================================================
# Configures Authentik as the central IdP replacing oauth2-proxy.
# Two proxy providers (forward_domain mode):
#   - "private": VIP email-restricted (most apps)
#   - "public": Any Google account (jellyseerr)
# Native OIDC providers: Grafana, Immich, Jellyfin
# Google OAuth is the only login source (no username/password).

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

data "authentik_flow" "default-source-enrollment" {
  slug = "default-source-enrollment"
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
  enrollment_flow     = data.authentik_flow.default-source-enrollment.id

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
  name         = "Admins"
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

resource "authentik_application" "public" {
  name              = "Public Services"
  slug              = "public-services"
  protocol_provider = authentik_provider_proxy.public.id
  meta_description  = "Services accessible to any authenticated Google user (Jellyseerr)"
}

# -----------------------------------------------------------------------------
# VIP Email Access Policy
# -----------------------------------------------------------------------------

resource "authentik_policy_expression" "vip_emails" {
  name       = "vip-email-restriction"
  expression = <<-EOT
    # Allow access only to VIP email addresses
    allowed_emails = ${jsonencode(var.authentik_vip_emails)}
    if not allowed_emails:
        # If no VIP emails configured, allow all (fail-open for initial setup)
        ak_message("No VIP emails configured, allowing all users")
        return True
    if request.user.email in allowed_emails:
        return True
    ak_message(f"Access denied: {{request.user.email}} is not a VIP user")
    return False
  EOT
}

# Bind VIP policy to private application
resource "authentik_policy_binding" "private_vip" {
  target = authentik_application.private.uuid
  policy = authentik_policy_expression.vip_emails.id
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

# Bind VIP policy to Grafana
resource "authentik_policy_binding" "grafana_vip" {
  target = authentik_application.grafana.uuid
  policy = authentik_policy_expression.vip_emails.id
  order  = 0
}

# Store Grafana OIDC credentials in Bitwarden for Kubernetes to consume
resource "bitwarden-secrets_secret" "grafana_oauth_client_id" {
  key        = "authentik-grafana-client-id"
  value      = authentik_provider_oauth2.grafana.client_id
  project_id = local.bitwarden_project_id
  note       = "Grafana OIDC client ID (via Authentik). Managed by Terraform."
}

resource "bitwarden-secrets_secret" "grafana_oauth_client_secret" {
  key        = "authentik-grafana-client-secret"
  value      = authentik_provider_oauth2.grafana.client_secret
  project_id = local.bitwarden_project_id
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
  project_id = local.bitwarden_project_id
  note       = "Immich OIDC client ID (via Authentik). Managed by Terraform."
}

resource "bitwarden-secrets_secret" "immich_oauth_client_secret" {
  key        = "authentik-immich-client-secret"
  value      = authentik_provider_oauth2.immich.client_secret
  project_id = local.bitwarden_project_id
  note       = "Immich OIDC client secret (via Authentik). Managed by Terraform."
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
  project_id = local.bitwarden_project_id
  note       = "Jellyfin OIDC client ID (via Authentik). Managed by Terraform."
}

resource "bitwarden-secrets_secret" "jellyfin_oauth_client_secret" {
  key        = "authentik-jellyfin-client-secret"
  value      = authentik_provider_oauth2.jellyfin.client_secret
  project_id = local.bitwarden_project_id
  note       = "Jellyfin OIDC client secret (via Authentik). Managed by Terraform."
}

# -----------------------------------------------------------------------------
# MCPJungle — Proxy application (VIP-restricted)
# -----------------------------------------------------------------------------
# Registers mcp.nerine.dev with the embedded outpost so Authentik's forward
# auth can resolve the host correctly and apply the VIP email access policy.

resource "authentik_application" "mcpjungle" {
  name              = "MCPJungle"
  slug              = "mcpjungle"
  protocol_provider = authentik_provider_proxy.private.id
  meta_description  = "Self-hosted MCP Gateway for AI agents"
  meta_launch_url   = "https://mcp.${var.authentik_domain}/mcp"
}

resource "authentik_policy_binding" "mcpjungle_vip" {
  target = authentik_application.mcpjungle.uuid
  policy = authentik_policy_expression.vip_emails.id
  order  = 0
}

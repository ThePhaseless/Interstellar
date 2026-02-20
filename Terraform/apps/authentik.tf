# =============================================================================
# Authentik Configuration — Identity Provider
# =============================================================================
# Configures Authentik as the central IdP replacing oauth2-proxy.
# Two proxy providers (forward_domain mode):
#   - "private": VIP email-restricted (most apps)
#   - "public": Any Google account (jellyseerr, jellyfin)
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
  skip_path_regex        = ""
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
  skip_path_regex        = ""
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
  meta_description  = "Services accessible to any authenticated Google user (Jellyseerr, Jellyfin)"
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
  name               = "authentik Embedded Outpost"
  protocol_providers = [
    authentik_provider_proxy.private.id,
    authentik_provider_proxy.public.id,
  ]
  config = jsonencode({
    authentik_host                       = "https://auth.${var.authentik_domain}/"
    authentik_host_browser               = ""
    authentik_host_insecure              = false
    log_level                            = "info"
    object_naming_template               = "ak-outpost-%(name)s"
    docker_network                       = null
    docker_map_ports                     = true
    docker_labels                        = null
    container_image                      = null
    kubernetes_replicas                   = 1
    kubernetes_namespace                  = "authentik"
    kubernetes_ingress_annotations        = {}
    kubernetes_ingress_secret_name        = ""
    kubernetes_ingress_class_name         = null
    kubernetes_service_type               = "ClusterIP"
    kubernetes_disabled_components        = ["deployment", "secret", "service", "prometheus servicemonitor", "ingress", "traefik middleware"]
    kubernetes_image_pull_secrets          = []
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

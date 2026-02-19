# =============================================================================
# Service Secrets — generated and stored in Bitwarden
# =============================================================================
# These secrets are created by Terraform with random values and synced to
# Kubernetes via ExternalSecrets operator. No manual secret creation needed.

# -----------------------------------------------------------------------------
# Random Password Generation
# -----------------------------------------------------------------------------

resource "random_password" "crowdsec_bouncer_key" {
  length  = 64
  special = false
}

resource "random_password" "grafana_admin_password" {
  length  = 32
  special = true
}

resource "random_password" "qbittorrent_password" {
  length  = 24
  special = true
}

resource "random_password" "immich_db_password" {
  length  = 32
  special = false
}

resource "random_password" "oauth2_proxy_cookie_secret" {
  length  = 32
  special = false
}

# -----------------------------------------------------------------------------
# Bitwarden Secrets — CrowdSec
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "crowdsec_api_key" {
  key        = "crowdsec-api-key"
  value      = random_password.crowdsec_bouncer_key.result
  project_id = local.bitwarden_project_id
  note       = "CrowdSec bouncer API key for Traefik plugin. Managed by Terraform."
}

# -----------------------------------------------------------------------------
# Bitwarden Secrets — Grafana
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "grafana_admin_password" {
  key        = "grafana-admin-password"
  value      = random_password.grafana_admin_password.result
  project_id = local.bitwarden_project_id
  note       = "Grafana admin password (internal admin account, not used for login — Google SSO via Authentik). Managed by Terraform."
}

resource "bitwarden-secrets_secret" "grafana_auth" {
  key        = "grafana-auth"
  value      = "admin:${random_password.grafana_admin_password.result}"
  project_id = local.bitwarden_project_id
  note       = "Grafana auth string (username:password) for Terraform provider. Managed by Terraform."
}

# -----------------------------------------------------------------------------
# Bitwarden Secrets — Discord (placeholder, user fills in later)
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "discord_webhook_url" {
  key        = "discord-webhook-url"
  value      = "https://discord.com/api/webhooks/placeholder"
  project_id = local.bitwarden_project_id
  note       = "Discord webhook URL for alerts. Update manually with actual webhook. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}

# -----------------------------------------------------------------------------
# Bitwarden Secrets — *arr API Keys (populated at runtime by init containers)
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "sonarr_api_key" {
  key        = "sonarr-api-key"
  value      = "placeholder-will-be-set-by-app"
  project_id = local.bitwarden_project_id
  note       = "Sonarr API key. Initially placeholder, updated by api-extractor init container. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}

resource "bitwarden-secrets_secret" "radarr_api_key" {
  key        = "radarr-api-key"
  value      = "placeholder-will-be-set-by-app"
  project_id = local.bitwarden_project_id
  note       = "Radarr API key. Initially placeholder, updated by api-extractor init container. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}

resource "bitwarden-secrets_secret" "prowlarr_api_key" {
  key        = "prowlarr-api-key"
  value      = "placeholder-will-be-set-by-app"
  project_id = local.bitwarden_project_id
  note       = "Prowlarr API key. Initially placeholder, updated by api-extractor init container. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}

# -----------------------------------------------------------------------------
# Bitwarden Secrets — qBittorrent
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "qbittorrent_username" {
  key        = "qbittorrent-username"
  value      = "admin"
  project_id = local.bitwarden_project_id
  note       = "qBittorrent WebUI username. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}

resource "bitwarden-secrets_secret" "qbittorrent_password" {
  key        = "qbittorrent-password"
  value      = random_password.qbittorrent_password.result
  project_id = local.bitwarden_project_id
  note       = "qBittorrent WebUI password. Managed by Terraform."
}

# -----------------------------------------------------------------------------
# Bitwarden Secrets — Copyparty
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "copyparty_admins" {
  key        = "copyparty-admins"
  value      = "admin:admin"
  project_id = local.bitwarden_project_id
  note       = "Copyparty admin credentials (user:pass). Update manually. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}

resource "bitwarden-secrets_secret" "copyparty_writers" {
  key        = "copyparty-writers"
  value      = "writer:writer"
  project_id = local.bitwarden_project_id
  note       = "Copyparty writer credentials (user:pass). Update manually. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}

# -----------------------------------------------------------------------------
# Bitwarden Secrets — Immich
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "immich_db_password" {
  key        = "immich-db-password"
  value      = random_password.immich_db_password.result
  project_id = local.bitwarden_project_id
  note       = "Immich PostgreSQL database password. Managed by Terraform."
}

# -----------------------------------------------------------------------------
# Bitwarden Secrets — OAuth2 Proxy (placeholder until Authentik migration)
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "oauth2_proxy_cookie_secret" {
  key        = "oauth2-proxy-cookie-secret"
  value      = random_password.oauth2_proxy_cookie_secret.result
  project_id = local.bitwarden_project_id
  note       = "OAuth2 Proxy cookie secret. Will be replaced by Authentik. Managed by Terraform."
}

resource "bitwarden-secrets_secret" "oauth2_proxy_google_client_id" {
  key        = "oauth2-proxy-google-client-id"
  value      = "placeholder-set-google-client-id"
  project_id = local.bitwarden_project_id
  note       = "Google OAuth client ID. Update manually. Will be replaced by Authentik. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}

resource "bitwarden-secrets_secret" "oauth2_proxy_google_client_secret" {
  key        = "oauth2-proxy-google-client-secret"
  value      = "placeholder-set-google-client-secret"
  project_id = local.bitwarden_project_id
  note       = "Google OAuth client secret. Update manually. Will be replaced by Authentik. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}

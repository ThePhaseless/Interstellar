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

resource "random_password" "authentik_secret_key" {
  length  = 50
  special = false
}

resource "random_password" "authentik_postgresql_password" {
  length  = 32
  special = false
}

resource "random_password" "authentik_bootstrap_token" {
  length  = 64
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
# Bitwarden Secrets — Authentik (Identity Provider)
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "authentik_secret_key" {
  key        = "authentik-secret-key"
  value      = random_password.authentik_secret_key.result
  project_id = local.bitwarden_project_id
  note       = "Authentik secret key for cookie signing and unique user IDs. Do NOT change after first install. Managed by Terraform."
}

resource "bitwarden-secrets_secret" "authentik_postgresql_password" {
  key        = "authentik-postgresql-password"
  value      = random_password.authentik_postgresql_password.result
  project_id = local.bitwarden_project_id
  note       = "Authentik PostgreSQL database password. Managed by Terraform."
}

resource "bitwarden-secrets_secret" "authentik_bootstrap_token" {
  key        = "authentik-bootstrap-token"
  value      = random_password.authentik_bootstrap_token.result
  project_id = local.bitwarden_project_id
  note       = "Authentik API bootstrap token for Terraform provider authentication. Managed by Terraform."
}

# -----------------------------------------------------------------------------
# Bitwarden Secrets — Google OAuth (shared by Authentik, Grafana, Immich)
# -----------------------------------------------------------------------------
# OAuth client is created manually in GCP Console. These placeholders are
# overwritten manually in Bitwarden after creating the client. See SETUP.md.

resource "bitwarden-secrets_secret" "google_oauth_client_id" {
  key        = "google-oauth-client-id"
  value      = "placeholder-set-google-client-id"
  project_id = local.bitwarden_project_id
  note       = "Google OAuth client ID. Create in GCP Console, update in Bitwarden. Used by Authentik, Grafana, Immich. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}

resource "bitwarden-secrets_secret" "google_oauth_client_secret" {
  key        = "google-oauth-client-secret"
  value      = "placeholder-set-google-client-secret"
  project_id = local.bitwarden_project_id
  note       = "Google OAuth client secret. Create in GCP Console, update in Bitwarden. Used by Authentik, Grafana, Immich. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}

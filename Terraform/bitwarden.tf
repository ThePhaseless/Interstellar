# =============================================================================
# Bitwarden Secrets Manager Configuration
# =============================================================================
# This file configures the Bitwarden Secrets Manager provider and data sources
# for all infrastructure secrets.

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
# The access token is provided via environment variable BWS_ACCESS_TOKEN
# which is set from GitHub Secrets or local .env file

provider "bitwarden" {
  # Access token is read from BWS_ACCESS_TOKEN environment variable
}

# -----------------------------------------------------------------------------
# Data Sources - Infrastructure Secrets from 'interstellar' Project
# -----------------------------------------------------------------------------

# Tailscale OAuth credentials
data "bitwarden_secret" "tailscale_oauth_client_id" {
  key = "tailscale-oauth-client-id"
}

data "bitwarden_secret" "tailscale_oauth_secret" {
  key = "tailscale-oauth-secret"
}

data "bitwarden_secret" "tailscale_tailnet" {
  key = "tailscale-tailnet"
}

# Cloudflare API token
data "bitwarden_secret" "cloudflare_api_token" {
  key = "cloudflare-api-token"
}

# Discord webhook for alerts
data "bitwarden_secret" "discord_webhook_url" {
  key = "discord-webhook-url"
}

# CrowdSec API key
data "bitwarden_secret" "crowdsec_api_key" {
  key = "crowdsec-api-key"
}

# Copyparty access groups (used for file write permissions)
data "bitwarden_secret" "copyparty_admins" {
  key = "copyparty-admins"
}

data "bitwarden_secret" "copyparty_writers" {
  key = "copyparty-writers"
}

# Tailscale Traefik IP (synced by Kubernetes CronJob)
# This is optional - if the secret doesn't exist, DNS records won't include Tailscale IP
data "bitwarden_secret" "tailscale_traefik_ip" {
  key = "tailscale-traefik-ip"
}


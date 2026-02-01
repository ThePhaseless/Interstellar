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

# Tailscale API credentials
data "bitwarden_secret" "tailscale_api_key" {
  key = "tailscale-api-key"
}

data "bitwarden_secret" "tailscale_tailnet" {
  key = "tailscale-tailnet"
}

data "bitwarden_secret" "tailscale_oauth_client_id" {
  key = "tailscale-oauth-client-id"
}

data "bitwarden_secret" "tailscale_oauth_secret" {
  key = "tailscale-oauth-secret"
}

# Proxmox API credentials
data "bitwarden_secret" "proxmox_api_token_id" {
  key = "proxmox-api-token-id"
}

data "bitwarden_secret" "proxmox_api_token_secret" {
  key = "proxmox-api-token-secret"
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

# Google OAuth credentials (Copyparty)
data "bitwarden_secret" "google_oauth_client_id" {
  key = "google-oauth-client-id"
}

data "bitwarden_secret" "google_oauth_client_secret" {
  key = "google-oauth-client-secret"
}

# Google OAuth credentials (Jellyfin)
data "bitwarden_secret" "jellyfin_google_oauth_client_id" {
  key = "jellyfin-google-oauth-client-id"
}

data "bitwarden_secret" "jellyfin_google_oauth_client_secret" {
  key = "jellyfin-google-oauth-client-secret"
}

# Copyparty access groups
data "bitwarden_secret" "copyparty_admins" {
  key = "copyparty-admins"
}

data "bitwarden_secret" "copyparty_writers" {
  key = "copyparty-writers"
}

# OCI Compartment ID
data "bitwarden_secret" "oci_compartment_id" {
  key = "oci-compartment-id"
}

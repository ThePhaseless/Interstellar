provider "bitwarden-secrets" {
  api_url      = "https://api.bitwarden.com"
  identity_url = "https://identity.bitwarden.com"
}

data "bitwarden-secrets_list_secrets" "all" {}

data "bitwarden-secrets_projects" "all" {}

locals {
  secret_key_to_id = { for s in data.bitwarden-secrets_list_secrets.all.secrets : s.key => s.id }
  bitwarden_project_id = try(
    [for p in data.bitwarden-secrets_projects.all.projects : p.id if p.name == "interstellar"][0],
    data.bitwarden-secrets_projects.all.projects[0].id
  )
  bitwarden_generated_project_id = try(
    [for p in data.bitwarden-secrets_projects.all.projects : p.id if p.name == "interstellar-generated"][0],
    null
  )

  # Common placeholder values that indicate a secret has not been properly set
  _placeholder_values = toset(["changeme", "change_me", "placeholder", "your-api-key", "default", "secret", "password", "username", "admin"])
}

data "bitwarden-secrets_secret" "sonarr_api_key" {
  id = local.secret_key_to_id[var.bitwarden_sonarr_api_key_name]

  lifecycle {
    postcondition {
      condition     = length(self.value) > 0 && !contains(local._placeholder_values, lower(self.value)) && can(regex("^[0-9a-f]{32}$", self.value))
      error_message = "Sonarr API key '${var.bitwarden_sonarr_api_key_name}' is empty, a placeholder, or not a valid 32-character hex API key."
    }
  }
}

data "bitwarden-secrets_secret" "radarr_api_key" {
  id = local.secret_key_to_id[var.bitwarden_radarr_api_key_name]

  lifecycle {
    postcondition {
      condition     = length(self.value) > 0 && !contains(local._placeholder_values, lower(self.value)) && can(regex("^[0-9a-f]{32}$", self.value))
      error_message = "Radarr API key '${var.bitwarden_radarr_api_key_name}' is empty, a placeholder, or not a valid 32-character hex API key."
    }
  }
}

data "bitwarden-secrets_secret" "prowlarr_api_key" {
  id = local.secret_key_to_id[var.bitwarden_prowlarr_api_key_name]

  lifecycle {
    postcondition {
      condition     = length(self.value) > 0 && !contains(local._placeholder_values, lower(self.value)) && can(regex("^[0-9a-f]{32}$", self.value))
      error_message = "Prowlarr API key '${var.bitwarden_prowlarr_api_key_name}' is empty, a placeholder, or not a valid 32-character hex API key."
    }
  }
}

data "bitwarden-secrets_secret" "authentik_bootstrap_token" {
  id = local.secret_key_to_id["authentik-bootstrap-token"]
}

data "bitwarden-secrets_secret" "google_oauth_client_id" {
  id = local.secret_key_to_id["google-oauth-client-id"]
}

data "bitwarden-secrets_secret" "google_oauth_client_secret" {
  id = local.secret_key_to_id["google-oauth-client-secret"]
}

data "bitwarden-secrets_secret" "owner_email" {
  id = local.secret_key_to_id["owner-email"]
}

data "bitwarden-secrets_secret" "discord_webhook_url" {
  id = local.secret_key_to_id["discord-webhook-url"]
}

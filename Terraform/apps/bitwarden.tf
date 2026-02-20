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
}

data "bitwarden-secrets_secret" "sonarr_api_key" {
  id = local.secret_key_to_id[var.bitwarden_sonarr_api_key_name]
}

data "bitwarden-secrets_secret" "radarr_api_key" {
  id = local.secret_key_to_id[var.bitwarden_radarr_api_key_name]
}

data "bitwarden-secrets_secret" "prowlarr_api_key" {
  id = local.secret_key_to_id[var.bitwarden_prowlarr_api_key_name]
}

data "bitwarden-secrets_secret" "qbittorrent_username" {
  id = local.secret_key_to_id[var.bitwarden_qbittorrent_username_name]
}

data "bitwarden-secrets_secret" "qbittorrent_password" {
  id = local.secret_key_to_id[var.bitwarden_qbittorrent_password_name]
}

terraform {
  required_version = ">= 1.11.4"

  required_providers {
    sonarr = {
      source  = "devopsarr/sonarr"
      version = ">= 3.4.2"
    }
    radarr = {
      source  = "devopsarr/radarr"
      version = ">= 2.3.5"
    }
    prowlarr = {
      source  = "devopsarr/prowlarr"
      version = ">= 3.2.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = ">= 4.25.0"
    }
    bitwarden-secrets = {
      source  = "bitwarden/bitwarden-secrets"
      version = "0.5.4-pre"
    }
  }
}

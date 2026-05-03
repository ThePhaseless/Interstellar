terraform {
  # Terraform 1.15.0 mis-handles the pinned Bitwarden prerelease during backend init.
  required_version = ">= 1.14.4, != 1.15.0"

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
    adguard = {
      source  = "gmichels/adguard"
      version = ">= 1.3.0"
    }
    authentik = {
      source  = "goauthentik/authentik"
      version = ">= 2025.12.0"
    }
    bitwarden-secrets = {
      source  = "bitwarden/bitwarden-secrets"
      version = "0.5.4-pre"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }

  }
}

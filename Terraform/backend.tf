terraform {
  required_version = ">= 1.15.1"

  # Authenticates from ~/.oci/config:
  # https://docs.oracle.com/en-us/iaas/Content/dev/terraform/configuring.htm
  # bucket and namespace come from -backend-config; bootstrap steps are in SETUP.md.
  backend "oci" {
    key = "interstellar/terraform.tfstate"
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.0.0"
    }

    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }

    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.10.0"
    }

    oci = {
      source  = "oracle/oci"
      version = ">= 8.0.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.0.0"
    }

    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.18.0"
    }

    bitwarden-secrets = {
      source  = "bitwarden/bitwarden-secrets"
      version = "1.0.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.36.0"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.49.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7.0"
    }
  }
}

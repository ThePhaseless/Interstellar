terraform {
  required_version = ">= 1.12.2"

  # OCI Object Storage backend for state storage
  # Authentication via ~/.oci/config file (SDK/CLI standard config)
  # See: https://docs.oracle.com/en-us/iaas/Content/dev/terraform/configuring.htm
  #
  # Bootstrap: terraform init -backend=false && terraform apply
  # Then: terraform init -migrate-state -backend-config="bucket=..." -backend-config="namespace=..."
  backend "oci" {
    key = "interstellar/terraform.tfstate"
  }

  required_providers {
    # Proxmox VM provisioning with GPU passthrough
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }

    # TalosOS cluster configuration
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.7.0"
    }

    # Oracle Cloud Infrastructure (VPS instance)
    oci = {
      source  = "oracle/oci"
      version = ">= 7.0.0"
    }

    # DNS management
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.0.0"
    }

    # Tailscale ACL policy management
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.18.0"
    }

    # Bitwarden Secrets Manager
    bitwarden = {
      source  = "bitwarden/bitwarden-secrets"
      version = ">= 0.1.0"
    }

    # Standard providers
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7.0"
    }
  }
}

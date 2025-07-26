terraform {
  # backend "oci" {
  #   bucket    = "terraform-state"
  #   namespace = "default"
  # }

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc03"
    }
    oci = {
      source  = "oracle/oci"
      version = ">=7.0.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">=5.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=4.0.0"
    }
  }
}

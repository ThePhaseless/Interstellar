terraform {
  required_version = ">= 1.12.2"
  
  # OCI Object Storage backend for state storage
  # Authentication via environment variables (OCI_ prefix):
  #   OCI_tenancy_ocid, OCI_user_ocid, OCI_fingerprint, OCI_private_key, OCI_region
  # 
  # First deployment bootstrap:
  # 1. Comment out backend "oci" block, use local state
  # 2. terraform apply -target=oci_objectstorage_bucket.terraform_state
  # 3. Uncomment backend block
  # 4. terraform init -migrate-state -backend-config="bucket=terraform-state" -backend-config="namespace=<your-namespace>"
  backend "oci" {
    key = "interstellar/terraform.tfstate"
  }

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc06"
    }
    oci = {
      source  = "oracle/oci"
      version = ">= 7.0.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=4.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}

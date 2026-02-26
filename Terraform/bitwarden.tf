# =============================================================================
# Bitwarden Secrets Manager Configuration
# =============================================================================
# This file configures the Bitwarden Secrets Manager provider and resources.
# All manual secrets are bootstrapped here as empty placeholders.

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "bitwarden-secrets" {
  api_url      = "https://api.bitwarden.com"
  identity_url = "https://identity.bitwarden.com"
}

# -----------------------------------------------------------------------------
# Project Lookup
# -----------------------------------------------------------------------------
data "bitwarden-secrets_projects" "all" {}

# Create a lookup map for existing secrets to avoid duplicate key errors
data "bitwarden-secrets_list_secrets" "all" {}

locals {
  secret_key_to_id = { for s in data.bitwarden-secrets_list_secrets.all.secrets : s.key => s.id }

  bitwarden_project_id = try(
    [for p in data.bitwarden-secrets_projects.all.projects : p.id if p.name == "interstellar"][0],
    data.bitwarden-secrets_projects.all.projects[0].id
  )
  bitwarden_generated_project_id = [for p in data.bitwarden-secrets_projects.all.projects : p.id if p.name == "interstellar-generated"][0]
}

# -----------------------------------------------------------------------------
# User-Managed Secrets (Terraform creates placeholders, user fills manually)
# -----------------------------------------------------------------------------

resource "bitwarden-secrets_secret" "tailscale_oauth_client_id" {
  key        = "tailscale-oauth-client-id"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "Tailnet management OAuth client ID (Main Key). Manually managed."
  lifecycle {
    ignore_changes = [value]
    postcondition {
      condition     = self.value != ""
      error_message = "Secret 'tailscale-oauth-client-id' is empty. Please fill it in Bitwarden."
    }
  }
}

resource "bitwarden-secrets_secret" "tailscale_oauth_secret" {
  key        = "tailscale-oauth-secret"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "Tailnet management OAuth client secret (Main Key). Manually managed."
  lifecycle {
    ignore_changes = [value]
    postcondition {
      condition     = self.value != ""
      error_message = "Secret 'tailscale-oauth-secret' is empty. Please fill it in Bitwarden."
    }
  }
}

resource "bitwarden-secrets_secret" "tailscale_tailnet" {
  key        = "tailscale-tailnet"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "Tailnet name (e.g. user.ts.net). Manually managed."
  lifecycle {
    ignore_changes = [value]
    postcondition {
      condition     = self.value != ""
      error_message = "Secret 'tailscale-tailnet' is empty. Please fill it in Bitwarden."
    }
  }
}

resource "bitwarden-secrets_secret" "cloudflare_api_token" {
  key        = "cloudflare-api-token"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "Cloudflare API token with DNS edit permissions. Manually managed."
  lifecycle {
    ignore_changes = [value]
    postcondition {
      condition     = self.value != ""
      error_message = "Secret 'cloudflare-api-token' is empty. Please fill it in Bitwarden."
    }
  }
}

resource "bitwarden-secrets_secret" "oci_config" {
  key        = "oci-config"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "OCI SDK configuration file content. Manually managed."
  lifecycle {
    ignore_changes = [value]
    postcondition {
      condition     = self.value != ""
      error_message = "Secret 'oci-config' is empty. Please fill it in Bitwarden."
    }
  }
}

resource "bitwarden-secrets_secret" "oci_private_key" {
  key        = "oci-private-key"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "OCI API private key (.pem). Manually managed."
  lifecycle {
    ignore_changes = [value]
    postcondition {
      condition     = self.value != ""
      error_message = "Secret 'oci-private-key' is empty. Please fill it in Bitwarden."
    }
  }
}

resource "bitwarden-secrets_secret" "hcloud_token" {
  key        = "hcloud-token"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "Hetzner Cloud API token. Manually managed."
  lifecycle {
    ignore_changes = [value]
    postcondition {
      condition     = self.value != ""
      error_message = "Secret 'hcloud-token' is empty. Please fill it in Bitwarden."
    }
  }
}

resource "bitwarden-secrets_secret" "tf_state_bucket" {
  key        = "tf-state-bucket"
  value      = "tf-state"
  project_id = local.bitwarden_project_id
  note       = "Name of the OCI bucket for Terraform state. Manually managed."
  lifecycle {
    ignore_changes = [value]
    postcondition {
      condition     = self.value != ""
      error_message = "Secret 'tf-state-bucket' is empty. Please fill it in Bitwarden."
    }
  }
}

resource "bitwarden-secrets_secret" "proxmox_user" {
  key        = "proxmox-user"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "Proxmox user for API authentication. Manually managed."
  lifecycle {
    ignore_changes = [value]
    postcondition {
      condition     = self.value != ""
      error_message = "Secret 'proxmox-user' is empty. Please fill it in Bitwarden."
    }
  }
}

resource "bitwarden-secrets_secret" "proxmox_token_id" {
  key        = "proxmox-token-id"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "Proxmox API token ID. Manually managed."
  lifecycle {
    ignore_changes = [value]
    postcondition {
      condition     = self.value != ""
      error_message = "Secret 'proxmox-token-id' is empty. Please fill it in Bitwarden."
    }
  }
}

resource "bitwarden-secrets_secret" "proxmox_api_token" {
  key        = "proxmox-api-token"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "Proxmox API token secret. Manually managed."
  lifecycle {
    ignore_changes = [value]
    postcondition {
      condition     = self.value != ""
      error_message = "Secret 'proxmox-api-token' is empty. Please fill it in Bitwarden."
    }
  }

}

resource "bitwarden-secrets_secret" "gh_app_id" {
  key        = "gh-app-id"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "GitHub App ID for CI authentication. Manually managed."
  lifecycle {
    ignore_changes = [value]
  }
}

resource "bitwarden-secrets_secret" "gh_app_private_key" {
  key        = "gh-app-private-key"
  value      = ""
  project_id = local.bitwarden_project_id
  note       = "GitHub App private key (PEM) for CI authentication. Manually managed."
  lifecycle {
    ignore_changes = [value]
  }
}

# -----------------------------------------------------------------------------
# Optional/Generated secrets
# -----------------------------------------------------------------------------

# Cluster API VIP (optional read path with var fallback)
data "bitwarden-secrets_secret" "cluster_vip" {
  count = contains(keys(local.secret_key_to_id), "cluster-vip") ? 1 : 0
  id    = local.secret_key_to_id["cluster-vip"]
}

resource "bitwarden-secrets_secret" "talosconfig" {
  key        = "talosconfig"
  value      = data.talos_client_configuration.cluster.talos_config
  note       = "Talosconfig for talosctl CLI access - managed by Terraform"
  project_id = local.bitwarden_generated_project_id
}

resource "bitwarden-secrets_secret" "oci_objectstorage_namespace" {
  key        = "oci-namespace"
  value      = data.oci_objectstorage_namespace.ns.namespace
  note       = "OCI Object Storage namespace for Terraform state bucket - managed by Terraform"
  project_id = local.bitwarden_generated_project_id
}

resource "bitwarden-secrets_secret" "cluster_vip" {
  key        = "cluster-vip"
  value      = var.cluster_vip
  note       = "Talos/Kubernetes control-plane virtual IP - managed by Terraform"
  project_id = local.bitwarden_generated_project_id
}

# -----------------------------------------------------------------------------
# Computed values from secrets
# -----------------------------------------------------------------------------
locals {
  tailscale_tailnet = bitwarden-secrets_secret.tailscale_tailnet.value

  oci_tenancy_ocid = regex("tenancy=([^\n]+)", bitwarden-secrets_secret.oci_config.value)[0]
  oci_user_ocid    = regex("user=([^\n]+)", bitwarden-secrets_secret.oci_config.value)[0]
  oci_region       = regex("region=([^\n]+)", bitwarden-secrets_secret.oci_config.value)[0]

  # Resolve cluster VIP from Bitwarden when available, otherwise use Terraform variable.
  cluster_vip = length(data.bitwarden-secrets_secret.cluster_vip) > 0 ? data.bitwarden-secrets_secret.cluster_vip[0].value : var.cluster_vip
}

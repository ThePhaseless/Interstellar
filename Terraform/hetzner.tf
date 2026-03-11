provider "hcloud" {
  token = var.hcloud_token
}

# SSH Key for BorgBackup
resource "tls_private_key" "borg_ssh_key" {
  algorithm = "ED25519"
}

# Borg Encryption Passphrase
resource "random_password" "borg_passphrase" {
  length  = 64
  special = false
}

# Hetzner Storage Box Password (must meet Hetzner policy: upper+lower+digit+special)
resource "random_password" "storagebox_password" {
  length           = 32
  special          = true
  override_special = "!@#$%&*"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# Storage Box
resource "hcloud_storage_box" "backups" {
  name             = "interstellar-backups"
  storage_box_type = var.hetzner_storagebox_type
  location         = var.hetzner_storagebox_location
  password         = random_password.storagebox_password.result

  access_settings = {
    ssh_enabled          = true
    reachable_externally = true
    samba_enabled        = false
    webdav_enabled       = false
    zfs_enabled          = true
  }

  snapshot_plan = {
    max_snapshots = 7
    minute        = 0
    hour          = 6
  }

  ssh_keys = [
    tls_private_key.borg_ssh_key.public_key_openssh
  ]

  delete_protection = true

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ssh_keys]
  }
}

# Bitwarden Secrets — BorgBackup
resource "bitwarden-secrets_secret" "borg_ssh_private_key" {
  key        = "borg-ssh-private-key"
  value      = tls_private_key.borg_ssh_key.private_key_openssh
  project_id = local.bitwarden_generated_project_id
  note       = "BorgBackup SSH private key (ED25519) for Hetzner Storage Box. Managed by Terraform."
}

resource "bitwarden-secrets_secret" "borg_passphrase" {
  key        = "borg-passphrase"
  value      = random_password.borg_passphrase.result
  project_id = local.bitwarden_generated_project_id
  note       = "BorgBackup encryption passphrase (repokey mode). Store safely — required for restore. Managed by Terraform."
}

resource "bitwarden-secrets_secret" "borg_repo_url" {
  key        = "borg-repo-url"
  value      = "ssh://${hcloud_storage_box.backups.username}@${hcloud_storage_box.backups.server}:23/./backups/immich"
  project_id = local.bitwarden_generated_project_id
  note       = "BorgBackup repository URL on Hetzner Storage Box. Managed by Terraform."
}

resource "bitwarden-secrets_secret" "borg_server_host" {
  key        = "borg-server-host"
  value      = hcloud_storage_box.backups.server
  project_id = local.bitwarden_generated_project_id
  note       = "Hetzner Storage Box FQDN for SSH known_hosts. Managed by Terraform."
}

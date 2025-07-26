provider "proxmox" {
  pm_api_url      = "https://${var.proxmox_host}:8006/api2/json"
  pm_tls_insecure = true
  pm_user         = "${var.proxmox_user}@pam"
}

locals {

  containers = {
    nickel = {
      memory           = 16384
      swap             = 8192
      ip               = "dhcp"
      boot_volume_size = "256G"
    }
  }

  root_fs_storage = "local-lvm"

  storage_name = "storage"
  storage_size = "1184G"
}


resource "proxmox_lxc" "containers" {
  for_each = local.containers

  ostemplate      = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  hostname        = each.key
  memory          = each.value.memory
  swap            = each.value.swap
  unprivileged    = false
  ssh_public_keys = tls_private_key.deployment_key.public_key_openssh

  features {
    fuse    = true
    nesting = true
  }

  onboot = true
  start  = true

  rootfs {
    storage = local.root_fs_storage
    size    = each.value.boot_volume_size
  }

  mountpoint {
    key     = 0
    slot    = 0
    storage = local.storage_name
    mp      = "/storage"
    size    = local.storage_size
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = each.value.ip == "dhcp" ? each.value.ip : "${each.value.ip}/24"
  }
}

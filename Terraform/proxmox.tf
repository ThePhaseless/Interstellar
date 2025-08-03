provider "proxmox" {
  pm_api_url      = "https://${var.proxmox_host}:8006/api2/json"
  pm_tls_insecure = true
  pm_user         = "${var.proxmox_user}@pam"
}

locals {

  containers = {
    nickel = {
      memory           = 24000
      swap             = 0
      ip               = "dhcp"
      boot_volume_size = "256G"
    }
  }

  root_fs_storage = "local-lvm"
}


resource "proxmox_lxc" "containers" {
  for_each = local.containers

  ostemplate      = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  target_node     = var.proxmox_host
  hostname        = each.key
  memory          = each.value.memory
  swap            = each.value.swap
  unprivileged    = false
  ssh_public_keys = data.tls_public_key.deployment_key.public_key_openssh

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
    key    = 0
    slot   = 0
    volume = "/Storage"
    mp     = "/Storage"
    size   = "0T"
  }

  # Devices - uncomment when passthrough devices are fixed
  # dynamic "mountpoint" {
  #   for_each = var.passthrough_devices
  #   iterator = device
  #   content {
  #     key    = 1 + index(var.passthrough_devices, device.value)
  #     slot   = 1 + index(var.passthrough_devices, device.value)
  #     size   = "32G"
  #     backup = false
  #     volume = device.value
  #     mp     = device.value
  #   }
  # }

  nameserver = "1.1.1.1"
  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = each.value.ip == "dhcp" ? each.value.ip : "${each.value.ip}/24"
  }
}

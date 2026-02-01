# =============================================================================
# Proxmox VM Configuration for TalosOS Cluster
# =============================================================================
# This file creates TalosOS VMs on Proxmox with GPU passthrough support

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = true # Self-signed cert
}

# -----------------------------------------------------------------------------
# TalosOS ISO Image
# -----------------------------------------------------------------------------
# Download TalosOS ISO with extensions pre-installed
resource "proxmox_virtual_environment_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node

  url       = "https://factory.talos.dev/image/${local.talos_schematic_id}/${var.talos_version}/nocloud-amd64.iso"
  file_name = "talos-${var.talos_version}-extensions.iso"

  overwrite = false
}

# Generate schematic ID for extensions
locals {
  talos_schematic_id = sha256(join(",", var.talos_extensions))
}

# -----------------------------------------------------------------------------
# TalosOS VMs
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "talos" {
  for_each = var.nodes

  name        = each.key
  node_name   = var.proxmox_node
  vm_id       = each.value.vmid
  description = "TalosOS ${each.value.gpu ? "GPU " : ""}node for Kubernetes cluster"

  # VM settings
  machine       = "q35"
  bios          = "ovmf"
  started       = true
  on_boot       = true
  tablet_device = false

  # Tags for organization
  tags = each.value.gpu ? ["talos", "kubernetes", "gpu"] : ["talos", "kubernetes"]

  # CPU configuration
  cpu {
    cores   = each.value.vcpus
    type    = "host"
    sockets = 1
  }

  # Memory configuration
  memory {
    dedicated = each.value.memory
    floating  = each.value.memory
  }

  # EFI disk for UEFI boot
  efi_disk {
    datastore_id      = var.storage_pool
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = false
  }

  # Boot disk
  disk {
    datastore_id = var.storage_pool
    interface    = "virtio0"
    size         = each.value.disk_size
    file_format  = "raw"
    iothread     = true
    discard      = "on"
  }

  # Boot from ISO for initial install
  cdrom {
    file_id   = proxmox_virtual_environment_download_file.talos_iso.id
    interface = "ide2"
  }

  # Network interface on VLAN 100
  network_device {
    bridge  = "vmbr1"
    model   = "virtio"
    vlan_id = 100
  }

  # Cloud-init for initial configuration (IP, gateway)
  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = each.value.gateway
      }
    }
  }

  # GPU passthrough for talos-1
  dynamic "hostpci" {
    for_each = each.value.gpu ? [1] : []
    content {
      device = "hostpci0"
      id     = each.value.gpu_device
      pcie   = true
      rombar = true
    }
  }

  # QEMU guest agent
  agent {
    enabled = true
    timeout = "60s"
    type    = "virtio"
  }

  # Serial console for Talos
  serial_device {}

  lifecycle {
    ignore_changes = [
      cdrom, # Ignore after initial boot
    ]
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "talos_node_ips" {
  description = "IP addresses of TalosOS nodes"
  value       = { for k, v in var.nodes : k => v.ip }
}

# =============================================================================
# Proxmox VM Configuration for TalosOS Cluster
# =============================================================================
# This file creates TalosOS VMs on Proxmox with GPU passthrough support

locals {
  talos_node_names    = sort(keys(var.nodes))
  talos_has_gpu_nodes = anytrue([for node in var.nodes : node.gpu])
  talos_node_ips = {
    for node_name, node in var.nodes : node_name => "192.168.1.${node.vmid}"
  }
}

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
# Download TalosOS base ISO with extensions pre-installed
resource "proxmox_virtual_environment_download_file" "talos_iso_base" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node

  url       = data.talos_image_factory_urls.base_image.urls.iso
  file_name = "talos-${var.talos_version}-extensions-${data.talos_image_factory_urls.base_image.schematic_id}.iso"
}

# Download TalosOS GPU ISO (only when at least one GPU node exists)
resource "proxmox_virtual_environment_download_file" "talos_iso_gpu" {
  count = local.talos_has_gpu_nodes ? 1 : 0

  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node

  url       = data.talos_image_factory_urls.gpu_image.urls.iso
  file_name = "talos-${var.talos_version}-gpu-extensions-${data.talos_image_factory_urls.gpu_image.schematic_id}.iso"
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
  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["scsi0", "ide0"]
  started       = true
  on_boot       = false

  operating_system {
    type = "l26"
  }

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
    floating  = 0
  }

  # EFI disk for UEFI boot
  efi_disk {
    datastore_id      = var.vm_os_datastore_id
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = false
  }

  # Talos OS boot disk
  disk {
    datastore_id = var.vm_os_datastore_id
    interface    = "scsi0"
    size         = each.value.os_disk_size
    file_format  = "raw"
    discard      = "on"
  }

  # Boot from ISO for initial install
  cdrom {
    file_id   = each.value.gpu ? proxmox_virtual_environment_download_file.talos_iso_gpu[0].id : proxmox_virtual_environment_download_file.talos_iso_base.id
    interface = "ide0"
  }

  # Network interface bridged directly to the home LAN
  network_device {
    bridge = var.proxmox_cluster_bridge_name
    model  = "virtio"
  }

  # Cloud-init network with static IP
  initialization {
    datastore_id = var.vm_os_datastore_id

    ip_config {
      ipv4 {
        address = "${local.talos_node_ips[each.key]}/24"
        gateway = "192.168.1.1"
      }
    }
  }

  # GPU passthrough for talos-1
  dynamic "hostpci" {
    for_each = each.value.gpu ? [1] : []
    content {
      device  = "hostpci0"
      mapping = each.value.gpu_device
      pcie    = true
      rombar  = true
    }
  }

  # QEMU guest agent
  agent {
    enabled = true
    timeout = "60s"
    type    = "virtio"
  }

  lifecycle {
    ignore_changes = [
      initialization,
      tags,
    ]

    precondition {
      condition     = !(each.value.data_disk_file_id != null && each.value.data_disk_size != null)
      error_message = "Set either data_disk_file_id (preserve existing data) or data_disk_size (create new data disk), not both."
    }
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "talos_node_ips" {
  description = "Discovered IP addresses of TalosOS nodes from Proxmox guest agent"
  value       = local.talos_node_ips
}

output "proxmox_vm_os_datastore_details" {
  description = "Configured Proxmox datastore for Talos VM OS disks"
  value = {
    configured_id = var.vm_os_datastore_id
    node_name     = var.proxmox_node
  }
}

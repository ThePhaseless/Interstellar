# =============================================================================
# Proxmox VM Configuration for TalosOS Cluster
# =============================================================================
# This file creates TalosOS VMs on Proxmox with GPU passthrough support

locals {
  talos_node_names = sort(keys(var.nodes))
  talos_node_ips = {
    for node_name in local.talos_node_names : node_name => try(
      [for ip in flatten(proxmox_virtual_environment_vm.talos[node_name].ipv4_addresses) : ip
      if ip != "" && !startswith(ip, "127.") && !startswith(ip, "169.254.")][0],
      null
    )
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
# Download TalosOS ISO with extensions pre-installed
resource "proxmox_virtual_environment_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node

  url       = data.talos_image_factory_urls.image.urls.iso
  file_name = "talos-${var.talos_version}-extensions-${data.talos_image_factory_urls.image.schematic_id}.iso"
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
    file_id   = proxmox_virtual_environment_download_file.talos_iso.id
    interface = "ide0"
  }

  # Network interface bridged directly to the home LAN
  network_device {
    bridge = var.proxmox_cluster_bridge_name
    model  = "virtio"
  }

  # Cloud-init network via DHCP
  initialization {
    datastore_id = var.vm_os_datastore_id

    ip_config {
      ipv4 {
        address = "dhcp"
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

  # Serial console for Talos
  serial_device {}

  lifecycle {
    ignore_changes = [
      initialization,
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

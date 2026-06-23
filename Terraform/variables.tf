variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL"
  type        = string
  default     = "https://carbon:8006"
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "carbon"
}

# Cluster Configuration
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "interstellar"
}

variable "cluster_vip" {
  description = "Talos/Kubernetes control-plane virtual IP for the API endpoint"
  type        = string
  default     = "192.168.1.100"
}

variable "cluster_domain" {
  description = "Domain for cluster services"
  type        = string
  default     = "nerine.dev"
}

# Node Configuration
variable "nodes" {
  description = "TalosOS node configuration"
  type = map(object({
    vmid              = number
    vcpus             = optional(number, 4)
    memory            = optional(number, 8192)
    os_disk_size      = optional(number, 64)
    data_disk_size    = optional(number)
    data_disk_file_id = optional(string)
    gpu               = optional(bool, false)
    gpu_device        = optional(string)
  }))
  default = {
    "talos-1" = {
      vmid           = 110
      vcpus          = 4
      memory         = 16384
      data_disk_size = 120
      gpu            = true
      gpu_device     = "gpu" # Intel Arc B580
    }
    "talos-2" = {
      vmid           = 111
      vcpus          = 6
      memory         = 8192
      data_disk_size = 120
    }
    "talos-3" = {
      vmid           = 112
      vcpus          = 6
      memory         = 8192
      data_disk_size = 120
    }
  }
}

# Network Configuration
variable "cluster_network" {
  description = "Cluster network CIDR for Talos nodes on the home LAN"
  type        = string
  default     = "192.168.1.0/24"
}

variable "vm_os_datastore_id" {
  description = "Proxmox datastore ID for Talos VM OS disks (SSD-backed, e.g. local-lvm). Not the ZFS media pool."
  type        = string
  default     = "local-zfs"
}

variable "proxmox_cluster_bridge_name" {
  description = "Name of the Proxmox bridge used for Talos VM networking"
  type        = string
  default     = "vmbr0"
}

# TalosOS Extensions
variable "talos_base_extensions" {
  description = "TalosOS extensions to install on all nodes"
  type        = list(string)
  default = [
    "siderolabs/iscsi-tools",
    "siderolabs/qemu-guest-agent",
    "siderolabs/util-linux-tools",
    "siderolabs/tailscale"
  ]
}

variable "talos_gpu_extensions" {
  description = "TalosOS extensions to install only on GPU nodes"
  type        = list(string)
  default = [
    "siderolabs/mei",
    "siderolabs/xe",
    # Temporary: ships i915/bmg_dmc.bin so xe runtime PM works.
    # The xe driver loads DMC firmware from i915/bmg_dmc.bin (legacy path),
    # but the Talos xe extension only ships /usr/lib/firmware/xe/, so runtime
    # PM was hard-disabled (~9W GPU idle floor). Remove once the upstream PR
    # to siderolabs/extensions (drm/xe/pkg.yaml) merges and the xe extension
    # includes i915/ firmware by default.
    "siderolabs/i915",
  ]
}

# renovate: datasource=github-releases depName=siderolabs/talos
variable "talos_version" {
  description = "TalosOS version"
  type        = string
  default     = "v1.13.4"
}

# renovate: datasource=github-releases depName=siderolabs/talos extractVersion=^v(?<version>.+)$ versioning=semver
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.36.2"
}

variable "tf_state_bucket" {
  description = "Name of the OCI Object Storage bucket for Terraform state"
  type        = string
  default     = "tf-state"
}

# Tailscale Configuration
variable "tailscale_magicdns_domain" {
  description = "Tailscale MagicDNS domain suffix (e.g. fold-hen.ts.net). Found via: tailscale status --json | jq -r '.MagicDNSSuffix'"
  type        = string
  default     = "fold-hen.ts.net"
}

variable "talos_api_endpoints" {
  description = "Reachable Talos API endpoint per node. Defaults to live Tailscale device IPs when available, and falls back to LAN IPs for first bootstrap before nodes join Tailscale."
  type        = map(string)
  default     = {}
}

variable "kubernetes_api_host" {
  description = "Reachable Talos MagicDNS hostname to use for Kubernetes provider access when the default bootstrap node hostname is not serving the API over Tailscale."
  type        = string
  default     = null
}

# Oracle Proxy Configuration
variable "proxy_public_access" {
  description = "Enable public HTTP (port 80) access to the Oracle proxy VPS. HTTPS (443) remains open; SSH is intended via Tailscale only."
  type        = bool
  default     = false
}

# Hetzner Cloud Configuration
variable "hcloud_token" {
  description = "Hetzner Cloud API token. Sourced from HCLOUD_TOKEN env var via setup-env.sh."
  type        = string
  sensitive   = true
}

variable "hetzner_storagebox_location" {
  description = "Hetzner Storage Box datacenter location"
  type        = string
  default     = "fsn1"
}

variable "hetzner_storagebox_type" {
  description = "Hetzner Storage Box product type (bx11=1TB, bx21=5TB, bx31=10TB, bx41=20TB)"
  type        = string
  default     = "bx11"
}

variable "github_repository" {
  description = "GitHub repository name (owner/repo)"
  type        = string
  default     = "ThePhaseless/Interstellar"
}

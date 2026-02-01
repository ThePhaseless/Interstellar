# =============================================================================
# Terraform Variables for TalosOS Migration
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox Configuration
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Cluster Configuration
# -----------------------------------------------------------------------------
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "interstellar"
}

variable "cluster_vip" {
  description = "Virtual IP for Kubernetes API (MetalLB)"
  type        = string
  default     = "10.100.0.100"
}

variable "cluster_domain" {
  description = "Domain for cluster services"
  type        = string
  default     = "nerine.dev"
}

# -----------------------------------------------------------------------------
# Node Configuration
# -----------------------------------------------------------------------------
variable "nodes" {
  description = "TalosOS node configuration"
  type = map(object({
    vmid       = number
    ip         = string
    gateway    = string
    vcpus      = number
    memory     = number
    disk_size  = number
    gpu        = bool
    gpu_device = optional(string)
  }))
  default = {
    "talos-1" = {
      vmid       = 101
      ip         = "10.100.0.11"
      gateway    = "10.100.0.1"
      vcpus      = 8
      memory     = 16384
      disk_size  = 64
      gpu        = true
      gpu_device = "0000:2f:00.0" # Intel Arc B580
    }
    "talos-2" = {
      vmid      = 102
      ip        = "10.100.0.12"
      gateway   = "10.100.0.1"
      vcpus     = 8
      memory    = 16384
      disk_size = 64
      gpu       = false
    }
    "talos-3" = {
      vmid      = 103
      ip        = "10.100.0.13"
      gateway   = "10.100.0.1"
      vcpus     = 8
      memory    = 16384
      disk_size = 64
      gpu       = false
    }
  }
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------
variable "cluster_network" {
  description = "Cluster network CIDR (VLAN 100)"
  type        = string
  default     = "10.100.0.0/24"
}

variable "storage_pool" {
  description = "Proxmox storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

# -----------------------------------------------------------------------------
# Oracle Cloud Configuration
# -----------------------------------------------------------------------------
variable "oci_tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

# -----------------------------------------------------------------------------
# Tailscale Configuration
# -----------------------------------------------------------------------------
variable "tailscale_tailnet" {
  description = "Tailscale tailnet name"
  type        = string
}

# -----------------------------------------------------------------------------
# TalosOS Extensions
# -----------------------------------------------------------------------------
variable "talos_extensions" {
  description = "TalosOS extensions to install"
  type        = list(string)
  default = [
    "siderolabs/qemu-guest-agent",
    "siderolabs/iscsi-tools",
    "siderolabs/util-linux-tools",
    "siderolabs/tailscale",
    "siderolabs/intel-ucode",
    "siderolabs/intel-driver-modules"
  ]
}

variable "talos_version" {
  description = "TalosOS version"
  type        = string
  default     = "v1.10.0"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32.0"
}
variable "tf_state_bucket" {
  description = "Name of the OCI Object Storage bucket for Terraform state"
  type        = string
  default     = "terraform-state"
}

# -----------------------------------------------------------------------------
# Tailscale Fallback DNS
# -----------------------------------------------------------------------------
variable "tailscale_traefik_ip" {
  description = "Tailscale IP of talos-traefik service for fallback DNS. Set after initial deployment."
  type        = string
  default     = ""  # Set this after running: tailscale status | grep talos-traefik
}

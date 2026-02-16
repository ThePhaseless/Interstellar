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
  description = "Talos/Kubernetes control-plane virtual IP for the API endpoint"
  type        = string
  default     = "192.168.1.100"
}

variable "use_vip_cluster_endpoint" {
  description = "Use cluster VIP as Talos cluster_endpoint after VIP is confirmed reachable"
  type        = bool
  default     = false
}

variable "traefik_lb_ip" {
  description = "MetalLB LoadBalancer IP for Traefik ingress service"
  type        = string
  default     = "192.168.1.101"
}

variable "adguard_dns_lb_ip" {
  description = "MetalLB LoadBalancer IP for AdGuard DNS service"
  type        = string
  default     = "192.168.1.102"
}

variable "cluster_local_lb_ip" {
  description = "Optional override for Kubernetes API endpoint migration when Bitwarden secret cluster-local-lb-ip is not yet available."
  type        = string
  default     = ""
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
      vmid       = 110
      gpu        = true
      gpu_device = "gpu" # Intel Arc B580
    }
    "talos-2" = {
      vmid = 111
    }
    "talos-3" = {
      vmid = 112
    }
  }
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# TalosOS Extensions
# -----------------------------------------------------------------------------
variable "talos_extensions" {
  description = "TalosOS extensions to install"
  type        = list(string)
  default = [
    "siderolabs/qemu-guest-agent",
    "siderolabs/util-linux-tools",
    "siderolabs/tailscale",
    "siderolabs/intel-ucode",
    "siderolabs/intel-driver-modules"
  ]
}

variable "talos_version" {
  description = "TalosOS version"
  type        = string
  default     = "v1.12.4"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.35.0"
}

variable "enable_talos_cluster_health_check" {
  description = "Whether to run talos_cluster_health during terraform apply. Disable during initial bootstrap to avoid long blocking reads."
  type        = bool
  default     = false
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
  default     = "" # Set this after running: tailscale status | grep talos-traefik
}

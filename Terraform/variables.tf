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
      memory         = 16384
      data_disk_size = 120
      gpu            = true
      gpu_device     = "gpu" # Intel Arc B580
    }
    "talos-2" = {
      vmid           = 111
      vcpus          = 6
      memory         = 12288
      data_disk_size = 120
    }
    "talos-3" = {
      vmid           = 112
      vcpus          = 6
      memory         = 12288
      data_disk_size = 120
    }
  }
}

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
    # xe loads DMC firmware from i915/bmg_dmc.bin, which the xe extension lacks; without
    # it runtime PM stays off (~9W idle). Drop once siderolabs/extensions drm/xe ships it.
    "siderolabs/i915",
  ]
}

# Installed OS version: bumping it upgrades every node in place through talos_machine.
variable "talos_version" {
  description = "TalosOS version"
  type        = string
  # renovate: datasource=github-releases depName=siderolabs/talos
  default = "v1.14.1"
}

# Machine-config generation contract, not the installed OS; bumping it regenerates every
# node's config, so change it deliberately rather than alongside talos_version.
variable "talos_config_version" {
  description = "Talos version the machine configuration is generated for"
  type        = string
  default     = "v1.13.9"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  # renovate: datasource=github-releases depName=kubernetes/kubernetes versioning=semver extractVersion=^v(?<version>.+)$
  default = "1.37.1"
}

variable "tf_state_bucket" {
  description = "Name of the OCI Object Storage bucket for Terraform state"
  type        = string
  default     = "tf-state"
}

variable "tailscale_magicdns_domain" {
  description = "Tailscale MagicDNS domain suffix (e.g. fold-hen.ts.net). Found via: tailscale status --json | jq -r '.MagicDNSSuffix'"
  type        = string
  default     = "fold-hen.ts.net"
}

variable "talos_api_endpoints" {
  description = "Reachable Talos API endpoint per node. Defaults to LAN IPs; CI overrides with Tailscale IPs resolved at runtime, since runners cannot reach the home LAN."
  type        = map(string)
  default     = {}
}

variable "kubernetes_api_host" {
  description = "Reachable Kubernetes API host for provider access. Defaults to the cluster VIP on the LAN; CI overrides with a Tailscale endpoint resolved at runtime."
  type        = string
  default     = null
}

variable "oracle_ssh_public_access" {
  description = "Temporarily open public SSH (port 22) to the Oracle VPS instances so a not-yet-enrolled VM can be reached for Tailscale bootstrap. Leave false outside of a bootstrap run."
  type        = bool
  default     = false
}

# Fails closed: the default reaches nothing, so a forgotten address breaks bootstrap instead of exposing sshd.
variable "oracle_ssh_source_cidr" {
  description = "Source CIDR allowed to reach port 22 while oracle_ssh_public_access is true. Scope this to the caller's own address."
  type        = string
  default     = "127.0.0.1/32"

  validation {
    condition = (
      can(cidrnetmask(var.oracle_ssh_source_cidr)) &&
      can(regex("/(2[4-9]|3[0-2])$", var.oracle_ssh_source_cidr))
    )
    error_message = "oracle_ssh_source_cidr must be a valid IPv4 CIDR of /24 or narrower - never 0.0.0.0/0. Pass the caller's own address, e.g. \"203.0.113.7/32\"."
  }
}

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

variable "billing_alert_email" {
  description = "Email address that receives OCI budget alerts when spend exceeds the Always Free allowance."
  type        = string
  default     = "admin@nerine.dev"
}

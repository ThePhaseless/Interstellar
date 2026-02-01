variable "ports" {
  description = "List of ports to be opened in the security group"
  type = map(object({
    port      = number
    protocol  = optional(string, "TCP")
    stateless = optional(bool, false)
  }))
  default = {
    SSH = { port : 22 },
    # HTTPS = { port : 443 },
    # Minecraft = { port : 25565 },
    Tailscale = { port : 41641, protocol : "UDP" },
    WireGuard = { port : 51820, protocol : "UDP" },
  }
}

variable "state_bucket_name" {
  description = "Name of the Object Storage bucket for Terraform state"
  type        = string
  default     = "terraform-state"
}

variable "ansible_bucket_name" {
  description = "Name of the Object Storage bucket for Ansible files"
  type        = string
  default     = "ansible"
}

variable "proxmox_host" {
  description = "Proxmox host address"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox user for API access"
  type        = string
  default     = "root"
}

# Unset after devices are fixed
# variable "passthrough_devices" {
#   description = "List of devices to pass through to the Proxmox container"
#   type        = list(string)
#   default = [
#     "/dev/nvidia0",
#     "/dev/nvidiactl",
#     "/dev/net/tun",
#   ]
# }

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the domain"
  type        = string
}

variable "tenancy_ocid" {
  description = "OCI Tenancy OCID (parent for the new compartment)"
  type        = string
}

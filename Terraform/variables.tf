variable "ports" {
  description = "List of ports to be opened in the security group"
  type = map(object({
    port     = number
    protocol = optional(string, "TCP")
  }))
  default = {
    SSH       = { port : 22 },
    HTTPS     = { port : 443 },
    Minecraft = { port : 25565 },
  }
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


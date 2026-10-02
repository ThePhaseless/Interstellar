variable "node" {
  description = "Node IP that Talos addresses the machine by"
  type        = string
}

variable "endpoint" {
  description = "Talos API endpoint used to reach the node"
  type        = string
}

variable "image" {
  description = "Talos installer image; a change upgrades the node"
  type        = string
}

variable "machine_configuration" {
  description = "Machine configuration YAML to apply"
  type        = string
  sensitive   = true
}

variable "client_configuration" {
  description = "Talos client configuration from talos_machine_secrets"
  type = object({
    ca_certificate     = string
    client_certificate = string
    client_key         = string
  })
}

variable "drain_kubeconfig" {
  description = "Kubeconfig used to drain the node; must reach an API server other than this node's"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "upgrade_gate" {
  description = "Wait for every attached Longhorn volume to be healthy before a new image is installed; needs a reachable Kubernetes API"
  type        = bool
}

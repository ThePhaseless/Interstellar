# =============================================================================
# TalosOS Cluster Configuration
# =============================================================================
# This file configures the TalosOS cluster using the Siderolabs Talos provider

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "talos" {}

locals {
  talos_cluster_endpoint_host = coalesce(local.cluster_local_lb_ip, local.talos_node_ips["talos-1"])
}

# -----------------------------------------------------------------------------
# Talos Machine Secrets
# -----------------------------------------------------------------------------
# Generate secrets for the cluster (PKI, tokens, etc.)
resource "talos_machine_secrets" "cluster" {}

# -----------------------------------------------------------------------------
# Talos Image Factory
# -----------------------------------------------------------------------------
# Get the schematic ID for the custom image with extensions
data "talos_image_factory_extensions_versions" "extensions" {
  talos_version = var.talos_version
  filters = {
    names = var.talos_extensions
  }
}

resource "talos_image_factory_schematic" "cluster" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.extensions.extensions_info[*].name
      }
    }
  })
}

data "talos_image_factory_urls" "image" {
  schematic_id  = talos_image_factory_schematic.cluster.id
  talos_version = var.talos_version
  platform      = "nocloud"
}


# -----------------------------------------------------------------------------
# Client Configuration
# -----------------------------------------------------------------------------
# Generate talosconfig for talosctl CLI access
data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [for node_name in local.talos_node_names : local.talos_node_ips[node_name]]
  nodes                = [for node_name in local.talos_node_names : local.talos_node_ips[node_name]]

  depends_on = [proxmox_virtual_environment_vm.talos]
}

# -----------------------------------------------------------------------------
# Machine Configuration - Control Plane
# -----------------------------------------------------------------------------
data "talos_machine_configuration" "controlplane" {
  for_each = var.nodes

  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${local.talos_cluster_endpoint_host}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = compact([
    # Minimal machine configuration for Proxmox Talos nodes
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              interface = "eth0"
              dhcp      = true
              vip = {
                ip = local.cluster_vip
              }
            }
          ]
        }

        # Install configuration with extensions
        install = {
          disk  = "/dev/sda"
          image = "factory.talos.dev/installer/${talos_image_factory_schematic.cluster.id}:${var.talos_version}"
          wipe  = false
        }

        # Prevent kubelet from selecting Tailscale 100.x as node primary IP.
        kubelet = {
          nodeIP = {
            validSubnets = [var.cluster_network]
          }
        }
      }
    }),

    # Minimal cluster-level settings
    yamlencode({
      cluster = {
        # Allow scheduling on control-plane nodes (combined nodes)
        allowSchedulingOnControlPlanes = true

        # Ensure etcd advertises LAN addresses, not Tailscale addresses.
        etcd = {
          advertisedSubnets = [var.cluster_network]
        }

        # API server configuration
        apiServer = {
          certSANs = [
            local.cluster_vip,
            "talos-operator.${local.tailscale_tailnet}.ts.net",
            "kubernetes.${var.cluster_domain}"
          ]
        }
      }
    }),

    # Configure tailscale extension (installed via image factory) so nodes authenticate on boot
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "ExtensionServiceConfig"
      name       = "tailscale"
      environment = [
        "TS_AUTHKEY=${tailscale_tailnet_key.cluster.key}",
        "TS_HOSTNAME=${each.key}",
        "TS_AUTH_ONCE=true"
      ]
    }),

    # GPU-specific kernel module forcing removed; rely on Talos defaults/extensions
    # to avoid apply failures when module names differ across Talos/kernel versions.
    null
  ])
}

# -----------------------------------------------------------------------------
# Apply Configuration to Nodes
# -----------------------------------------------------------------------------
resource "talos_machine_configuration_apply" "controlplane" {
  for_each = var.nodes

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane[each.key].machine_configuration
  node                        = local.talos_node_ips[each.key]

  depends_on = [proxmox_virtual_environment_vm.talos]
}

# -----------------------------------------------------------------------------
# Bootstrap the Cluster
# -----------------------------------------------------------------------------
resource "talos_machine_bootstrap" "cluster" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = local.talos_node_ips["talos-1"]

  depends_on = [talos_machine_configuration_apply.controlplane]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "talos_schematic_id" {
  description = "Talos Factory schematic ID for the custom image"
  value       = talos_image_factory_schematic.cluster.id
}

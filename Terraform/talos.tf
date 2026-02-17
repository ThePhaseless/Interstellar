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
  talos_node_is_gpu           = { for node_name, node in var.nodes : node_name => node.gpu }
}

# -----------------------------------------------------------------------------
# Talos Machine Secrets
# -----------------------------------------------------------------------------
# Generate secrets for the cluster (PKI, tokens, etc.)
resource "talos_machine_secrets" "cluster" {}

# -----------------------------------------------------------------------------
# Talos Image Factory
# -----------------------------------------------------------------------------
# Get the schematic IDs for custom images with node-specific extensions
data "talos_image_factory_extensions_versions" "base_extensions" {
  talos_version = var.talos_version
  filters = {
    names = distinct(var.talos_base_extensions)
  }
}

resource "talos_image_factory_schematic" "base" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.base_extensions.extensions_info[*].name
      }
    }
  })
}

data "talos_image_factory_urls" "base_image" {
  schematic_id  = talos_image_factory_schematic.base.id
  talos_version = var.talos_version
  platform      = "nocloud"
}

data "talos_image_factory_extensions_versions" "gpu_extensions" {
  talos_version = var.talos_version
  filters = {
    names = distinct(concat(var.talos_base_extensions, var.talos_gpu_extensions))
  }
}

resource "talos_image_factory_schematic" "gpu" {
  schematic = yamlencode({
    customization = {
      extraKernelArgs = ["video=efifb:off"]
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.gpu_extensions.extensions_info[*].name
      }
    }
  })
}

data "talos_image_factory_urls" "gpu_image" {
  schematic_id  = talos_image_factory_schematic.gpu.id
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
        certSANs = [
          each.key,
          "${each.key}.${var.tailscale_magicdns_domain}",
          local.talos_node_ips[each.key],
        ]

        kubelet = {
          nodeIP = {
            validSubnets = [var.cluster_network]
          }
        }

        network = {
          nameservers = ["1.1.1.1", "8.8.8.8"]
          interfaces = [
            {
              deviceSelector = {
                busPath = "0*" # Match first PCI network device (virtio NIC)
              }
              dhcp      = false
              addresses = ["${local.talos_node_ips[each.key]}/24"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = "192.168.1.1"
                }
              ]
            }
          ]
        }

        # Install configuration with extensions
        install = {
          disk  = "/dev/sda"
          image = each.value.gpu ? "factory.talos.dev/installer/${talos_image_factory_schematic.gpu.id}:${var.talos_version}" : "factory.talos.dev/installer/${talos_image_factory_schematic.base.id}:${var.talos_version}"
          wipe  = false
        }
      }
    }),

    # Minimal cluster-level settings
    yamlencode({
      cluster = {
        # Allow scheduling on control-plane nodes (combined nodes)
        allowSchedulingOnControlPlanes = true

        # API server configuration
        apiServer = {
          certSANs = [
            local.cluster_vip,
            "kubernetes.${var.cluster_domain}",
            each.key,
            "${each.key}.${var.tailscale_magicdns_domain}"
          ]
        }

        # Restrict etcd to LAN subnet (exclude Tailscale IPs)
        etcd = {
          advertisedSubnets = [var.cluster_network]
        }
      }
    }),

    # Tailscale extension service configuration
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "ExtensionServiceConfig"
      name       = "tailscale"
      environment = [
        "TS_AUTHKEY=${tailscale_tailnet_key.cluster.key}",
        "TS_HOSTNAME=${each.key}",
        "TS_EXTRA_ARGS=--accept-routes --advertise-tags=tag:cluster --accept-dns=false",
        "TS_ROUTES=${var.cluster_network}",
        "TS_AUTH_ONCE=true",
      ]
    })
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
  description = "Talos Factory schematic IDs for base and GPU images"
  value = {
    base = talos_image_factory_schematic.base.id
    gpu  = talos_image_factory_schematic.gpu.id
  }
}

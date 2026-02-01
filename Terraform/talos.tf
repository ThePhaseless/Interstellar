# =============================================================================
# TalosOS Cluster Configuration
# =============================================================================
# This file configures the TalosOS cluster using the Siderolabs Talos provider

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "talos" {}

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

# -----------------------------------------------------------------------------
# Client Configuration
# -----------------------------------------------------------------------------
# Generate talosconfig for talosctl CLI access
data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [for node in var.nodes : node.ip]
  nodes                = [for node in var.nodes : node.ip]
}

# -----------------------------------------------------------------------------
# Machine Configuration - Control Plane
# -----------------------------------------------------------------------------
data "talos_machine_configuration" "controlplane" {
  for_each = var.nodes

  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.cluster_vip}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = [
    # Network configuration
    yamlencode({
      machine = {
        network = {
          hostname = each.key
          interfaces = [
            {
              interface = "eth0"
              addresses = ["${each.value.ip}/24"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = each.value.gateway
                }
              ]
            }
          ]
          nameservers = ["1.1.1.1", "8.8.8.8"]
        }

        # Install configuration with extensions
        install = {
          disk       = "/dev/vda"
          image      = "factory.talos.dev/installer/${talos_image_factory_schematic.cluster.id}:${var.talos_version}"
          bootloader = true
          wipe       = false
        }

        # Tailscale extension configuration
        pods = [
          {
            apiVersion = "v1"
            kind       = "Pod"
            metadata = {
              name      = "tailscale"
              namespace = "kube-system"
            }
          }
        ]

        # iSCSI configuration for LongHorn
        kubelet = {
          extraMounts = [
            {
              destination = "/var/lib/iscsi"
              type        = "bind"
              source      = "/var/lib/iscsi"
              options     = ["rbind", "rshared", "rw"]
            }
          ]
        }

        # Sysctls for networking
        sysctls = {
          "net.core.somaxconn"            = "65535"
          "net.core.netdev_max_backlog"   = "4096"
          "net.ipv4.tcp_max_syn_backlog"  = "4096"
          "fs.inotify.max_user_watches"   = "1048576"
          "fs.inotify.max_user_instances" = "8192"
          "fs.inotify.max_queued_events"  = "16384"
        }

        # Time sync
        time = {
          servers = ["time.cloudflare.com"]
        }
      }
    }),

    # Cluster configuration
    yamlencode({
      cluster = {
        # Allow scheduling on control-plane nodes (combined nodes)
        allowSchedulingOnControlPlanes = true

        # Network configuration
        network = {
          cni = {
            name = "flannel"
          }
          podSubnets     = ["10.244.0.0/16"]
          serviceSubnets = ["10.96.0.0/12"]
        }

        # Proxy configuration
        proxy = {
          disabled = false
        }

        # API server configuration
        apiServer = {
          certSANs = [
            var.cluster_vip,
            "talos-operator.${local.tailscale_tailnet}.ts.net",
            "kubernetes.${var.cluster_domain}"
          ]
        }

        # etcd configuration
        etcd = {
          advertisedSubnets = [var.cluster_network]
        }
      }
    }),

    # GPU configuration for talos-1
    each.value.gpu ? yamlencode({
      machine = {
        kernel = {
          modules = [
            { name = "i915" }
          ]
        }
      }
    }) : null
  ]
}

# -----------------------------------------------------------------------------
# Apply Configuration to Nodes
# -----------------------------------------------------------------------------
resource "talos_machine_configuration_apply" "controlplane" {
  for_each = var.nodes

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane[each.key].machine_configuration
  node                        = each.value.ip

  depends_on = [proxmox_virtual_environment_vm.talos]
}

# -----------------------------------------------------------------------------
# Bootstrap the Cluster
# -----------------------------------------------------------------------------
resource "talos_machine_bootstrap" "cluster" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.nodes["talos-1"].ip

  depends_on = [talos_machine_configuration_apply.controlplane]
}

# -----------------------------------------------------------------------------
# Cluster Health Check
# -----------------------------------------------------------------------------
data "talos_cluster_health" "cluster" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  control_plane_nodes  = [for node in var.nodes : node.ip]
  endpoints            = [for node in var.nodes : node.ip]

  depends_on = [talos_machine_bootstrap.cluster]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "talos_schematic_id" {
  description = "Talos Factory schematic ID for the custom image"
  value       = talos_image_factory_schematic.cluster.id
}

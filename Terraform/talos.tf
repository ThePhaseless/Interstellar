locals {
  talos_cluster_endpoint_host = var.cluster_vip
  talos_node_hostnames = {
    for node_name in local.talos_node_names : node_name => "${node_name}.${var.tailscale_magicdns_domain}"
  }
  talos_node_api_endpoints = {
    for node_name in local.talos_node_names : node_name => lookup(var.talos_api_endpoints, node_name, local.talos_node_ips[node_name])
  }
  talos_longhorn_data_disk_symlink = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1"
  talos_bootstrap_node_name        = local.talos_node_names[0]
  talos_bootstrap_node_endpoint    = local.talos_node_api_endpoints[local.talos_bootstrap_node_name]

  # A node's own API server goes down with its reboot, so each drain goes through the next node's.
  talos_drain_api_endpoints = {
    for i, node_name in local.talos_node_names :
    node_name => local.talos_node_api_endpoints[local.talos_node_names[(i + 1) % length(local.talos_node_names)]]
  }

  talos_installer_images = {
    for node_name, node in var.nodes :
    node_name => "factory.talos.dev/installer/${node.gpu ? talos_image_factory_schematic.gpu.id : talos_image_factory_schematic.base.id}:${var.talos_version}"
  }
}

resource "talos_machine_secrets" "cluster" {}

resource "talos_image_factory_schematic" "base" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = distinct(var.talos_base_extensions)
      }
    }
  })
}

data "talos_image_factory_urls" "base_image" {
  schematic_id  = talos_image_factory_schematic.base.id
  talos_version = var.talos_version
  platform      = "nocloud"
}

resource "talos_image_factory_schematic" "gpu" {
  schematic = yamlencode({
    customization = {
      extraKernelArgs = ["video=efifb:off", "xe.disable_display=1", "console=ttyS0"]
      systemExtensions = {
        officialExtensions = distinct(concat(var.talos_base_extensions, var.talos_gpu_extensions))
      }
    }
  })
}

data "talos_image_factory_urls" "gpu_image" {
  schematic_id  = talos_image_factory_schematic.gpu.id
  talos_version = var.talos_version
  platform      = "nocloud"
}


data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [for node_name in local.talos_node_names : local.talos_node_hostnames[node_name]]
  nodes                = [for node_name in local.talos_node_names : local.talos_node_hostnames[node_name]]

  depends_on = [proxmox_virtual_environment_vm.talos]
}

resource "talos_cluster_kubeconfig" "cluster" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoint             = local.talos_bootstrap_node_endpoint
  node                 = local.talos_bootstrap_node_endpoint

  depends_on = [talos_cluster.cluster]

  lifecycle {
    ignore_changes = [endpoint, node]
  }
}

data "talos_machine_configuration" "controlplane" {
  for_each = var.nodes

  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${local.talos_cluster_endpoint_host}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = var.talos_config_version
  kubernetes_version = var.kubernetes_version

  config_patches = compact([
    # auto must stay "off": the generated base sets auto: stable, which Talos rejects alongside a hostname.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      hostname   = each.key
      auto       = "off"
    }),

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

          extraConfig = {
            imageMaximumGCAge = "168h"

            # Talos defaults these to 30s/10s; kubelet rejects the config if
            # either is non-zero alongside shutdownGracePeriodByPodPriority.
            shutdownGracePeriod             = "0s"
            shutdownGracePeriodCriticalPods = "0s"

            shutdownGracePeriodByPodPriority = [
              { priority = 0, shutdownGracePeriodSeconds = 120 },
              { priority = 1000000000, shutdownGracePeriodSeconds = 60 },
            ]
          }
        }

        network = {
          nameservers = ["1.1.1.1", "8.8.8.8"]
          interfaces = [
            {
              deviceSelector = {
                busPath = "0*" # Matches every PCI NIC; safe only while each VM has one
              }
              dhcp      = false
              addresses = ["${local.talos_node_ips[each.key]}/24"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = "192.168.1.1"
                }
              ]
              vip = {
                ip = var.cluster_vip
              }
            }
          ]
        }

        install = {
          disk  = "/dev/sda"
          image = local.talos_installer_images[each.key]
        }
      }
    }),

    local.talos_node_has_data_disk[each.key] ? yamlencode({
      machine = {
        kubelet = {
          extraMounts = [
            {
              destination = "/var/mnt/longhorn"
              type        = "bind"
              source      = "/var/mnt/longhorn"
              options     = ["bind", "rshared", "rw"]
            }
          ]
        }
      }
    }) : null,

    local.talos_node_has_data_disk[each.key] ? yamlencode({
      apiVersion = "v1alpha1"
      kind       = "UserVolumeConfig"
      name       = "longhorn"
      volumeType = "disk"
      provisioning = {
        diskSelector = {
          match = "disk.transport == 'virtio' && '${local.talos_longhorn_data_disk_symlink}' in disk.symlinks"
        }
      }
      filesystem = {
        type = "ext4"
      }
    }) : null,

    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true

        apiServer = {
          certSANs = [
            local.cluster_vip,
            "kubernetes.${var.cluster_domain}",
            each.key,
            "${each.key}.${var.tailscale_magicdns_domain}"
          ]
        }

        # Keep etcd off the Tailscale IPs.
        etcd = {
          advertisedSubnets = [var.cluster_network]
        }

        # Flannel alone ignores NetworkPolicy; this adds kube-network-policies to enforce it.
        network = {
          cni = {
            name = "flannel"
            flannel = {
              kubeNetworkPoliciesEnabled = true
            }
          }
        }
      }
    }),

    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "ExtensionServiceConfig"
      name       = "tailscale"
      environment = [
        "TS_AUTHKEY=${tailscale_tailnet_key.cluster.key}",
        "TS_HOSTNAME=${each.key}",
        "TS_EXTRA_ARGS=--accept-routes --advertise-tags=tag:node --accept-dns=false",
        "TS_AUTH_ONCE=true",
      ]
    }),
  ])
}

ephemeral "talos_cluster_kubeconfig" "drain" {
  for_each = var.nodes

  cluster_name    = var.cluster_name
  endpoint        = "https://${local.talos_drain_api_endpoints[each.key]}:6443"
  machine_secrets = talos_machine_secrets.cluster.machine_secrets
}

# Upgrades reboot the node and for_each cannot chain instances, so applies that bump
# talos_version must run with -parallelism=1 or all three control planes reboot at once.
resource "talos_machine" "controlplane" {
  for_each = var.nodes

  client_configuration  = talos_machine_secrets.cluster.client_configuration
  machine_configuration = data.talos_machine_configuration.controlplane[each.key].machine_configuration
  node                  = local.talos_node_ips[each.key]
  endpoint              = local.talos_node_api_endpoints[each.key]
  image                 = local.talos_installer_images[each.key]

  drain_on_upgrade                = true
  kubeconfig_wo                   = ephemeral.talos_cluster_kubeconfig.drain[each.key].kubeconfig_raw
  ignore_kubernetes_upgrade_drift = true

  depends_on = [proxmox_virtual_environment_vm.talos]
}

resource "talos_cluster" "cluster" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = local.talos_node_ips[local.talos_bootstrap_node_name]
  endpoint             = local.talos_bootstrap_node_endpoint
  control_plane_nodes  = [for node_name in local.talos_node_names : local.talos_node_ips[node_name]]
  kubernetes_version   = var.kubernetes_version

  depends_on = [talos_machine.controlplane]
}

removed {
  from = talos_machine_configuration_apply.controlplane

  lifecycle {
    destroy = false
  }
}

removed {
  from = talos_machine_bootstrap.cluster

  lifecycle {
    destroy = false
  }
}

output "talos_schematic_id" {
  description = "Talos Factory schematic IDs for base and GPU images"
  value = {
    base = talos_image_factory_schematic.base.id
    gpu  = talos_image_factory_schematic.gpu.id
  }
  sensitive = true
}

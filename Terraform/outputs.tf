output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint currently used by Terraform/Talos"
  value       = "https://${local.talos_cluster_endpoint_host}:6443"
  sensitive   = true
}

output "cluster_nodes" {
  description = "Map of cluster node names to discovered IPs"
  value       = local.talos_node_ips
  sensitive   = true
}

output "access_instructions" {
  description = "Instructions for accessing the cluster"
  sensitive   = true
  value       = <<-EOT
    Cluster access:
    1. Get talosconfig:
       mkdir -p ~/.talos && chmod 700 ~/.talos
       bws secret list --output json --color no | jq -r '.[] | select(.key=="talosconfig") | .value' > ~/.talos/config
       chmod 600 ~/.talos/config

     2. Configure kubectl from Talos:
       talosctl -n ${local.talos_node_names[0]}.${var.tailscale_magicdns_domain} kubeconfig ~/.kube/config

     3. Optional:
       tailscale configure kubeconfig ${local.talos_node_names[0]}

     4. Verify:
       talosctl health --nodes ${join(",", [for node_name in local.talos_node_names : "${node_name}.${var.tailscale_magicdns_domain}"])}
       kubectl get nodes

     5. Endpoints:
       - API Server: ${local.talos_node_names[0]}.${var.tailscale_magicdns_domain}:6443
       - Traefik: talos-traefik.${var.tailscale_magicdns_domain}

     6. Check Tailscale extension:
       talosctl -n ${local.talos_node_names[0]}.${var.tailscale_magicdns_domain} service ext-tailscale
       talosctl -n ${local.talos_node_names[0]}.${var.tailscale_magicdns_domain} logs ext-tailscale
  EOT
}

output "ansible_inventory" {
  description = "Ansible inventory for Oracle VPS configuration"
  value = yamlencode({
    all = {
      hosts = {
        oracle = {
          ansible_host                 = oci_core_instance.proxy.public_ip
          ansible_user                 = "ubuntu"
          ansible_ssh_private_key_file = "~/.ssh/oracle_ed25519"
        }
      }
      vars = {
        tailscale_authkey = tailscale_tailnet_key.cluster.key
      }
    }
  })
  sensitive = true
}

output "storage_box_server" {
  description = "Hetzner Storage Box FQDN"
  value       = hcloud_storage_box.backups.server
  sensitive   = true
}

output "storage_box_username" {
  description = "Hetzner Storage Box primary username"
  value       = hcloud_storage_box.backups.username
  sensitive   = true
}

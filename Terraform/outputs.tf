# =============================================================================
# Terraform Outputs
# =============================================================================
# Consolidated outputs for the TalosOS cluster infrastructure

# -----------------------------------------------------------------------------
# Cluster Outputs
# -----------------------------------------------------------------------------
output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint currently used by Terraform/Talos"
  value       = "https://${local.talos_cluster_endpoint_host}:6443"
}

output "cluster_nodes" {
  description = "Map of cluster node names to discovered IPs"
  value       = local.talos_node_ips
}

# -----------------------------------------------------------------------------
# Access Instructions
# -----------------------------------------------------------------------------
output "access_instructions" {
  description = "Instructions for accessing the cluster"
  value       = <<-EOT
    ============================================================
    TalosOS Cluster Access Instructions
    ============================================================

    1. Get talosconfig from Bitwarden:
       mkdir -p ~/.talos && chmod 700 ~/.talos
       bws secret list --output json --color no | jq -r '.[] | select(.key=="talosconfig") | .value' > ~/.talos/config
       chmod 600 ~/.talos/config

     2. Configure kubectl directly from Talos (recommended for bootstrap):
       talosctl -n ${local.talos_node_ips["talos-1"]} kubeconfig ~/.kube/config

     3. (Optional) Configure kubectl via Tailscale auth proxy:
       tailscale configure kubeconfig talos-1

     4. Verify cluster health:
       talosctl health --nodes ${join(",", [for node_name in local.talos_node_names : local.talos_node_ips[node_name]])}
       kubectl get nodes

     5. Access via Tailscale MagicDNS:
       - API Server: talos-1.<tailnet>.ts.net:6443
       - Traefik: talos-traefik.<tailnet>.ts.net

    ============================================================
  EOT
}

# -----------------------------------------------------------------------------
# Ansible Inventory
# -----------------------------------------------------------------------------
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

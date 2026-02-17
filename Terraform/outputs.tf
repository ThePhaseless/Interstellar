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
  sensitive   = true
  value       = <<-EOT
    ============================================================
    TalosOS Cluster Access Instructions
    ============================================================

    1. Get talosconfig from Bitwarden:
       mkdir -p ~/.talos && chmod 700 ~/.talos
       bws secret list --output json --color no | jq -r '.[] | select(.key=="talosconfig") | .value' > ~/.talos/config
       chmod 600 ~/.talos/config

     2. Configure kubectl directly from Talos (via Tailscale):
       talosctl -n talos-1.${var.tailscale_magicdns_domain} kubeconfig ~/.kube/config

     3. (Optional) Configure kubectl via Tailscale auth proxy:
       tailscale configure kubeconfig talos-1

     4. Verify cluster health:
       talosctl health --nodes ${join(",", [for node_name in local.talos_node_names : "${node_name}.${var.tailscale_magicdns_domain}"])}
       kubectl get nodes

     5. Access via Tailscale MagicDNS:
       - API Server: talos-1.${var.tailscale_magicdns_domain}:6443
       - Traefik: talos-traefik.${var.tailscale_magicdns_domain}

     6. Verify Tailscale extension on nodes:
       talosctl -n talos-1.${var.tailscale_magicdns_domain} service ext-tailscale
       talosctl -n talos-1.${var.tailscale_magicdns_domain} logs ext-tailscale

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

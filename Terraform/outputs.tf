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
  description = "Kubernetes API endpoint"
  value       = "https://${var.cluster_vip}:6443"
}

output "cluster_nodes" {
  description = "Map of cluster node names to IPs"
  value       = { for k, v in var.nodes : k => v.ip }
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

    1. Save talosconfig:
       terraform output -raw talosconfig > ~/.talos/config

    2. Save kubeconfig:
       terraform output -raw kubeconfig > ~/.kube/config

    3. Or use Tailscale for kubectl access:
       tailscale configure kubeconfig talos-operator

    4. Verify cluster health:
       talosctl health --nodes ${join(",", [for n in var.nodes : n.ip])}
       kubectl get nodes

    5. Access via Tailscale MagicDNS:
       - API Server: talos-operator.${var.tailscale_tailnet}.ts.net:6443
       - Traefik: talos-traefik.${var.tailscale_tailnet}.ts.net

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
          ansible_host                 = oci_core_instance.oracle_vps.public_ip
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

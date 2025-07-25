provider "tls" {
}

resource "tls_private_key" "deployment_key" {
  algorithm = "RSA"
}

resource "local_sensitive_file" "deployment_key" {
  content  = tls_private_key.deployment_key.private_key_pem
  filename = "${path.root}/../$2.pem"
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.root}/Templates/inventory.tpl", {
    pve_ip   = var.proxmox_host
    pve_user = var.proxmox_user

    oracle_servers = {
      (oci_core_instance.instance.public_ip)= "ubuntu"
    },

    private_key_path = "${path.root}/../$2.pem"
    proxy_user       = var.proxmox_user
    proxy_host       = var.proxmox_host

  })
  filename = "${path.root}/../Ansible/inventory.ini"
}

# Save a list of Proxmox container IDs to a YAML file for Ansible
resource "local_file" "proxmox_containers" {
  content = yamlencode({
    containers = [for container in proxmox_lxc.containers : container.id]
    pve_user   = var.proxmox_user
    pve_ip     = var.proxmox_host
  })

  filename = "${path.root}/../Ansible/vars/proxmox.yaml"
}


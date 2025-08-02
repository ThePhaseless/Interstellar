provider "tls" {
}

resource "tls_private_key" "deployment_key" {
  algorithm = "RSA"
}

data "oci_objectstorage_object" "existing_deployment_key" {
  bucket    = var.ansible_bucket_name
  namespace = data.oci_objectstorage_namespace.namespace.namespace
  object    = "deployment_key.pem"
}

data "tls_public_key" "deployment_key" {
  private_key_pem = data.oci_objectstorage_object.existing_deployment_key.content_length != null ? data.oci_objectstorage_object.existing_deployment_key.content : tls_private_key.deployment_key.private_key_pem
}

resource "oci_objectstorage_object" "deployment_key" {
  object    = "deployment_key.pem"
  bucket    = oci_objectstorage_bucket.ansible_files.name
  namespace = data.oci_objectstorage_namespace.namespace.namespace
  content   = data.tls_public_key.deployment_key.private_key_pem
}

resource "oci_objectstorage_object" "inventory" {
  object    = "inventory.yaml"
  bucket    = oci_objectstorage_bucket.ansible_files.name
  namespace = data.oci_objectstorage_namespace.namespace.namespace

  content = yamlencode({
    proxmox = {
      hosts = {
        "pve" = {
          ansible_host = var.proxmox_host
          ansible_user = var.proxmox_user
        }
      }
    }

    oracle = {
      hosts = {
        "vps" = {
          ansible_host = oci_core_instance.instance.public_ip
          ansible_user = "ubuntu"
        }
      }
    },

    containers = {
      vars = {
        ansible_user            = "root"
        ansible_ssh_common_args = "-o ProxyJump ${var.proxmox_user}@${var.proxmox_host}"
      }
    }

    all = {
      vars = {
        ansible_ssh_private_key_file = "../.private/deployment_key.pem"
      }
    }
  })
}

resource "oci_objectstorage_object" "containers" {
  object    = "containers.yaml"
  bucket    = oci_objectstorage_bucket.ansible_files.name
  namespace = data.oci_objectstorage_namespace.namespace.namespace

  content = yamlencode({
    containers = [for container in proxmox_lxc.containers : container.id]
    pve_user   = var.proxmox_user
    pve_ip     = var.proxmox_host
  })
}

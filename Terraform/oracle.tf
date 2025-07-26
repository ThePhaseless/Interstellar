provider "oci" {
}

provider "cloudflare" {
}

locals {
  ubuntu_version = "22.04"
  machine = {
    name  = "argon"
    shape = "VM.Standard.A1.Flex"

    # Free limits are 200 GB / 24 GB / 4 cores
    disk_size_GB = 200
    memory_GB    = 24
    cpu_count    = 4
  }
}

resource "oci_identity_compartment" "compartment" {
  description = "Compartment for Terraform resources."
  name        = "TerraformCompartment"
}

data "oci_objectstorage_namespace" "namespace" {
  compartment_id = oci_identity_compartment.compartment.id
}

resource "oci_objectstorage_bucket" "terraform_state" {
  compartment_id = oci_identity_compartment.compartment.id
  name           = var.bucket_name
  namespace      = data.oci_objectstorage_namespace.namespace.namespace
  versioning     = "Enabled"
}

data "oci_core_images" "images" {
  compartment_id = oci_identity_compartment.compartment.id

  operating_system         = "Canonical Ubuntu"
  operating_system_version = local.ubuntu_version
  shape                    = local.machine.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

module "vcn" {
  source         = "oracle-terraform-modules/vcn/oci"
  version        = "3.6.0"
  compartment_id = oci_identity_compartment.compartment.id

  vcn_name                = "TerraformVCN"
  create_internet_gateway = true
}

resource "oci_core_security_list" "security_list" {
  compartment_id = oci_identity_compartment.compartment.id
  vcn_id         = module.vcn.vcn_id
  display_name   = "TerraformSecurityList"

  egress_security_rules {
    stateless   = false
    description = "Allow all outbound traffic"
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  dynamic "ingress_security_rules" {

    for_each = var.ports
    content {
      stateless   = false
      source      = "0.0.0.0/0"
      source_type = "CIDR_BLOCK"
      description = "Allow ${ingress_security_rules.key} ingress traffic"
      # Get protocol numbers from https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
      protocol = ingress_security_rules.value.protocol == "TCP" ? "6" : "17"


      dynamic "tcp_options" {                                                                           # Use dynamic block for tcp_options
        for_each = ingress_security_rules.value.protocol == "TCP" ? [ingress_security_rules.value] : [] # Only create if protocol is TCP
        content {
          min = tcp_options.value.port
          max = tcp_options.value.port
        }
      }


      dynamic "udp_options" {                                                                           # Use dynamic block for udp_options
        for_each = ingress_security_rules.value.protocol == "UDP" ? [ingress_security_rules.value] : [] # Only create if protocol is UDP
        content {
          min = udp_options.value.port
          max = udp_options.value.port
        }
      }
    }
  }
}

resource "oci_core_subnet" "subnet" {
  compartment_id = oci_identity_compartment.compartment.id
  vcn_id         = module.vcn.vcn_id
  display_name   = "TerraformSubnet"
  cidr_block     = "10.0.0.0/24"

  route_table_id = module.vcn.ig_route_id

  security_list_ids = [
    oci_core_security_list.security_list.id
  ]

}

data "oci_identity_availability_domains" "availability_domains" {
  compartment_id = oci_identity_compartment.compartment.id
}

resource "oci_core_instance" "instance" {
  compartment_id      = oci_identity_compartment.compartment.id
  availability_domain = data.oci_identity_availability_domains.availability_domains.availability_domains[0].name
  shape               = local.machine.shape

  shape_config {
    ocpus         = local.machine.cpu_count
    memory_in_gbs = local.machine.memory_GB
  }
  source_details {
    source_type             = "image"
    boot_volume_size_in_gbs = local.machine.disk_size_GB
    source_id               = data.oci_core_images.images.images[0].id
  }

  display_name = local.machine.name

  create_vnic_details {
    assign_public_ip = true
    subnet_id        = oci_core_subnet.subnet.id
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.deployment_key.public_key_openssh
  }

  preserve_boot_volume = false
}



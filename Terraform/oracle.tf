provider "oci" {
}

provider "cloudflare" {
}

locals {
  ubuntu_version = "24.04"
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
  name           = var.state_bucket_name
  namespace      = data.oci_objectstorage_namespace.namespace.namespace
  versioning     = "Enabled"

  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_objectstorage_bucket" "ansible_files" {
  compartment_id = oci_identity_compartment.compartment.id
  name           = var.ansible_bucket_name
  namespace      = data.oci_objectstorage_namespace.namespace.namespace
}

data "oci_core_images" "images" {
  compartment_id = oci_identity_compartment.compartment.id

  operating_system         = "Canonical Ubuntu"
  operating_system_version = local.ubuntu_version
  shape                    = local.machine.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_vcn" "vcn" {
  compartment_id = oci_identity_compartment.compartment.id
  display_name   = "TerraformVCN"

  cidr_blocks = ["10.0.0.0/16"]
}

resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = oci_identity_compartment.compartment.id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "TerraformInternetGateway"
}

resource "oci_core_security_list" "security_list" {
  compartment_id = oci_identity_compartment.compartment.id
  vcn_id         = oci_core_vcn.vcn.id
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
      stateless   = ingress_security_rules.value.stateless
      source      = "0.0.0.0/0"
      source_type = "CIDR_BLOCK"
      description = "Allow ${ingress_security_rules.key} ingress traffic"
      # Get protocol numbers from https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
      protocol = ingress_security_rules.value.protocol == "TCP" ? "6" : "17"


      dynamic "tcp_options" {
        for_each = ingress_security_rules.value.protocol == "TCP" ? [ingress_security_rules.value] : []
        content {
          min = tcp_options.value.port
          max = tcp_options.value.port
        }
      }


      dynamic "udp_options" {
        for_each = ingress_security_rules.value.protocol == "UDP" ? [ingress_security_rules.value] : []
        content {
          min = udp_options.value.port
          max = udp_options.value.port
        }
      }
    }
  }
}

resource "oci_core_route_table" "route_table" {
  compartment_id = oci_identity_compartment.compartment.id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "TerraformRouteTable"

  route_rules {
    network_entity_id = oci_core_internet_gateway.internet_gateway.id
    destination       = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "subnet" {
  compartment_id = oci_identity_compartment.compartment.id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "TerraformSubnet"
  cidr_block     = oci_core_vcn.vcn.cidr_blocks[0]
  route_table_id = oci_core_route_table.route_table.id

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
    ssh_authorized_keys = data.tls_public_key.deployment_key.public_key_openssh
  }

  preserve_boot_volume = false
}

resource "cloudflare_record" "dns_record" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  value   = oci_core_instance.instance.public_ip
  type    = "A"
  ttl     = 1
  proxied = false
}

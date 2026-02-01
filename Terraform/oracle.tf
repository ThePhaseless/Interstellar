# =============================================================================
# Oracle Cloud Infrastructure (OCI) Configuration
# =============================================================================
# This file provisions the Oracle VPS for HAProxy entry point

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
# OCI provider authentication via environment variables:
# OCI_tenancy_ocid, OCI_user_ocid, OCI_fingerprint, OCI_private_key, OCI_region

provider "oci" {
  # Authentication handled by environment variables
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

# Get availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = data.bitwarden_secret.oci_compartment_id.value
}

# Get Ubuntu image
data "oci_core_images" "ubuntu" {
  compartment_id           = data.bitwarden_secret.oci_compartment_id.value
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

# VCN (Virtual Cloud Network)
resource "oci_core_vcn" "main" {
  compartment_id = data.bitwarden_secret.oci_compartment_id.value
  display_name   = "interstellar-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "interstellar"
}

# Internet Gateway
resource "oci_core_internet_gateway" "main" {
  compartment_id = data.bitwarden_secret.oci_compartment_id.value
  vcn_id         = oci_core_vcn.main.id
  display_name   = "interstellar-igw"
  enabled        = true
}

# Route Table
resource "oci_core_route_table" "main" {
  compartment_id = data.bitwarden_secret.oci_compartment_id.value
  vcn_id         = oci_core_vcn.main.id
  display_name   = "interstellar-rt"

  route_rules {
    network_entity_id = oci_core_internet_gateway.main.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

# Security List
resource "oci_core_security_list" "main" {
  compartment_id = data.bitwarden_secret.oci_compartment_id.value
  vcn_id         = oci_core_vcn.main.id
  display_name   = "interstellar-sl"

  # Egress: Allow all outbound
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # Ingress: SSH
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "SSH access"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Ingress: HTTP
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = false
    description = "HTTP traffic"

    tcp_options {
      min = 80
      max = 80
    }
  }

  # Ingress: HTTPS
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = false
    description = "HTTPS traffic"

    tcp_options {
      min = 443
      max = 443
    }
  }

  # Ingress: Tailscale UDP
  ingress_security_rules {
    protocol    = "17" # UDP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "Tailscale WireGuard"

    udp_options {
      min = 41641
      max = 41641
    }
  }
}

# Subnet
resource "oci_core_subnet" "main" {
  compartment_id             = data.bitwarden_secret.oci_compartment_id.value
  vcn_id                     = oci_core_vcn.main.id
  display_name               = "interstellar-subnet"
  cidr_block                 = "10.0.1.0/24"
  route_table_id             = oci_core_route_table.main.id
  security_list_ids          = [oci_core_security_list.main.id]
  prohibit_public_ip_on_vnic = false
  dns_label                  = "main"
}

# -----------------------------------------------------------------------------
# Compute Instance
# -----------------------------------------------------------------------------

# SSH Key
resource "tls_private_key" "oracle_ssh" {
  algorithm = "ED25519"
}

# -----------------------------------------------------------------------------
# Proxy VPS (Minimal - just HAProxy)
# -----------------------------------------------------------------------------
resource "oci_core_instance" "proxy" {
  compartment_id      = data.bitwarden_secret.oci_compartment_id.value
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "oracle-proxy"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.main.id
    assign_public_ip = true
    display_name     = "oracle-proxy-vnic"
    hostname_label   = "proxy"
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.oracle_ssh.public_key_openssh
    user_data = base64encode(<<-EOF
      #!/bin/bash
      apt-get update
      apt-get install -y curl apt-transport-https ca-certificates gnupg

      # Unattended upgrades with auto-reboot
      apt-get install -y unattended-upgrades
      cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'UPGRADES'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
UPGRADES
      systemctl enable unattended-upgrades
    EOF
    )
  }

  freeform_tags = {
    "project"    = "interstellar"
    "managed_by" = "terraform"
    "purpose"    = "haproxy-entry-point"
  }

  lifecycle {
    ignore_changes = [metadata["user_data"]]
  }
}

# -----------------------------------------------------------------------------
# Compute VPS (Remaining resources for general workloads)
# -----------------------------------------------------------------------------
resource "oci_core_instance" "compute" {
  compartment_id      = data.bitwarden_secret.oci_compartment_id.value
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "oracle-compute"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 3
    memory_in_gbs = 18
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.main.id
    assign_public_ip = true
    display_name     = "oracle-compute-vnic"
    hostname_label   = "compute"
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.oracle_ssh.public_key_openssh
    user_data = base64encode(<<-EOF
      #!/bin/bash
      apt-get update
      apt-get install -y curl apt-transport-https ca-certificates gnupg

      # Unattended upgrades with auto-reboot
      apt-get install -y unattended-upgrades
      cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'UPGRADES'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
UPGRADES
      systemctl enable unattended-upgrades
    EOF
    )
  }

  freeform_tags = {
    "project"    = "interstellar"
    "managed_by" = "terraform"
    "purpose"    = "general-compute"
  }

  lifecycle {
    ignore_changes = [metadata["user_data"]]
  }
}

# -----------------------------------------------------------------------------
# Store SSH Key in Bitwarden
# -----------------------------------------------------------------------------
resource "bitwarden_secret" "oracle_ssh_private_key" {
  key        = "oracle-ssh-private-key"
  value      = tls_private_key.oracle_ssh.private_key_openssh
  project_id = data.bitwarden_project.interstellar.id
  note       = "SSH private key for Oracle VPS instances. Managed by Terraform."
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "oracle_proxy_public_ip" {
  description = "Public IP of proxy VPS"
  value       = oci_core_instance.proxy.public_ip
}

output "oracle_compute_public_ip" {
  description = "Public IP of compute VPS"
  value       = oci_core_instance.compute.public_ip
}

output "oracle_ssh_private_key" {
  description = "SSH private key for Oracle VPS (sensitive)"
  value       = tls_private_key.oracle_ssh.private_key_openssh
  sensitive   = true
}

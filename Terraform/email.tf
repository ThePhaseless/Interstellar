resource "oci_email_email_domain" "main" {
  compartment_id = oci_identity_compartment.main.id
  name           = var.cluster_domain
  description    = "Email domain for Interstellar homelab services"

  freeform_tags = {
    "project"    = "interstellar"
    "managed_by" = "terraform"
  }
}

resource "oci_email_dkim" "main" {
  email_domain_id = oci_email_email_domain.main.id
  name            = "interstellar-dkim"
  description     = "DKIM signing key for ${var.cluster_domain}"
}

resource "oci_email_sender" "noreply" {
  compartment_id = oci_identity_compartment.main.id
  email_address  = "noreply@${var.cluster_domain}"

  freeform_tags = {
    "project"    = "interstellar"
    "managed_by" = "terraform"
  }
}

resource "oci_identity_smtp_credential" "postfix" {
  description = "SMTP credential for Postfix relay - Interstellar homelab"
  user_id     = local.oci_user_ocid
}

resource "cloudflare_dns_record" "dkim" {
  zone_id = data.cloudflare_zone.main.id
  name    = trimsuffix(oci_email_dkim.main.dns_subdomain_name, ".")
  content = trimsuffix(oci_email_dkim.main.cname_record_value, ".")
  type    = "CNAME"
  ttl     = 300
  comment = "OCI Email Delivery DKIM verification record"
}

resource "cloudflare_dns_record" "spf" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  content = "v=spf1 include:rp.oracleemaildelivery.com ~all"
  type    = "TXT"
  ttl     = 300
  comment = "SPF record for OCI Email Delivery"
}

resource "bitwarden-secrets_secret" "smtp_host" {
  key        = "smtp-host"
  value      = "smtp.email.${local.oci_region}.oci.oraclecloud.com"
  project_id = local.bitwarden_generated_project_id
  note       = "OCI Email Delivery SMTP endpoint. Managed by Terraform."
}

resource "bitwarden-secrets_secret" "smtp_username" {
  key        = "smtp-username"
  value      = oci_identity_smtp_credential.postfix.username
  project_id = local.bitwarden_generated_project_id
  note       = "OCI Email Delivery SMTP username. Managed by Terraform."
}

resource "bitwarden-secrets_secret" "smtp_password" {
  key        = "smtp-password"
  value      = oci_identity_smtp_credential.postfix.password
  project_id = local.bitwarden_generated_project_id
  note       = "OCI Email Delivery SMTP password. Only available at creation time. Managed by Terraform."
}

output "smtp_endpoint" {
  description = "OCI Email Delivery SMTP endpoint"
  value       = "smtp.email.${local.oci_region}.oci.oraclecloud.com"
  sensitive   = true
}

output "smtp_sender" {
  description = "Approved sender email address"
  value       = oci_email_sender.noreply.email_address
  sensitive   = true
}

output "email_domain_state" {
  description = "Email domain verification state"
  value       = oci_email_email_domain.main.state
  sensitive   = true
}

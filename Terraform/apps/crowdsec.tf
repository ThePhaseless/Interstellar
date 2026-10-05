resource "random_password" "crowdsec_web_ui" {
  length  = 32
  special = false
}

resource "bitwarden-secrets_secret" "crowdsec_web_ui_password" {
  key        = "crowdsec-web-ui-password"
  value      = random_password.crowdsec_web_ui.result
  project_id = local.bitwarden_generated_project_id
  note       = "CrowdSec LAPI machine password for crowdsec-web-ui. Managed by Terraform."
}

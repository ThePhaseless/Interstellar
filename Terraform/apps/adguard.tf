data "kubernetes_resources" "traefik_tailscale_secrets" {
  api_version    = "v1"
  kind           = "Secret"
  namespace      = "tailscale"
  label_selector = "tailscale.com/parent-resource=traefik,tailscale.com/parent-resource-type=svc"
}

locals {
  traefik_tailscale_ips = jsondecode(base64decode(data.kubernetes_resources.traefik_tailscale_secrets.objects[0].data["device_ips"]))
  traefik_tailscale_ip  = local.traefik_tailscale_ips[0]
}

resource "adguard_config" "main" {
  dns = {
    upstream_dns = [
      "https://1.1.1.1/dns-query",
      "https://1.0.0.1/dns-query",
    ],
  }
}

resource "adguard_user_rules" "nerine_dev_user_rules" {
  rules = [
    "||nerine.dev^$dnsrewrite=NOERROR;A;${var.adguard_traefik_local_ip},client=192.168.0.0/16",
    "||*.nerine.dev^$dnsrewrite=NOERROR;A;${var.adguard_traefik_local_ip},client=192.168.0.0/16",
    # Tailscale clients with real Tailscale CGNAT IPs
    "||nerine.dev^$dnsrewrite=NOERROR;A;${local.traefik_tailscale_ip},client=100.64.0.0/10",
    "||*.nerine.dev^$dnsrewrite=NOERROR;A;${local.traefik_tailscale_ip},client=100.64.0.0/10",
    # Tailscale clients via operator pods (appear as pod CIDR in AdGuard due to NAT)
    "||nerine.dev^$dnsrewrite=NOERROR;A;${local.traefik_tailscale_ip},client=10.244.0.0/16",
    "||*.nerine.dev^$dnsrewrite=NOERROR;A;${local.traefik_tailscale_ip},client=10.244.0.0/16",
  ]
}

resource "adguard_list_filter" "adguard_dns_filter" {
  name    = "AdGuard DNS filter"
  url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"
  enabled = true
}

resource "adguard_list_filter" "adaway_default" {
  name    = "AdAway Default Blocklist"
  url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt"
  enabled = true
}

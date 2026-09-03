resource "adguard_config" "main" {
  dhcp = {
    enabled   = false
    interface = "eth0"

    ipv4_settings = {
      gateway_ip     = "192.168.1.1"
      range_start    = "192.168.1.2"
      range_end      = "192.168.1.254"
      subnet_mask    = "255.255.255.0"
      lease_duration = 86400
    }
  }

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
    "@@||brightdata.com^$important",
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

resource "adguard_list_filter" "hagezi_normal" {
  name    = "HaGeZi's Normal Blocklist"
  url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_34.txt"
  enabled = true
}

resource "adguard_list_filter" "steven_black" {
  name    = "Steven Black's List"
  url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_33.txt"
  enabled = true
}

resource "adguard_list_filter" "oisd_big" {
  name    = "OISD Blocklist Big"
  url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_27.txt"
  enabled = true
}

resource "adguard_list_filter" "cert_polska" {
  name    = "POL: CERT Polska List of malicious domains"
  url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_41.txt"
  enabled = true
}

resource "adguard_list_filter" "polish_pihole" {
  name    = "POL: Polish filters for Pi-hole"
  url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_14.txt"
  enabled = true
}
